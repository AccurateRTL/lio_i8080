# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0


# test_my_design.py (simple)


import logging
import random
import math
import itertools
import cocotb
import os

import cocotb_test.simulator
import pytest

from cocotb.triggers import FallingEdge, RisingEdge, Timer, Event
from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotb.regression import TestFactory
from cocotb.clock import Clock
from cocotbext.axi import AxiBus, AxiRam
from cocotbext.axi import AxiLiteBus, AxiLiteRam, AxiLiteMaster


async def cycle_reset(dut):
    dut.arstn.setimmediatevalue(0)
    for i in range(10):
        await RisingEdge(dut.aclk)
        
    dut.arstn.setimmediatevalue(1)
    for i in range(10):
        await RisingEdge(dut.aclk)

I8080_VERSION_REG_OFS         = 0x00
I8080_GONFIG_REG_0_OFS        = 0x04
I8080_GONFIG_REG_1_OFS        = 0x08
I8080_WINDOW_REG_OFS          = 0x0C
I8080_CMD_FIFO_OFS            = 0x10
I8080_DATA_FIFO_OFS           = 0x14
I8080_CSN_REG_OFS             = 0x18

WRITE_CMD     = 0
WRITE_PARAM   = 1
WRITE_N_PARAM = 2
SYNC_CMD      = 3

IF_MODE_8B  = 1
IF_MODE_16B = 2

DC_BIT_OFFSET = 31

MEM_WRITE_CMD = 0x1C
MEM_READ_CMD  = 0x1D

I8080_CMD  = 0
I8080_DATA = 1

async def cycle_te(dut):
  while(1):
    dut.TE.setimmediatevalue(0)
    await Timer(1000, units="ns")
    dut.TE.setimmediatevalue(1)
    await Timer(100, units="ns")

async def i8080_write_trans(cfg_axil_master, dc, data):
    await cfg_axil_master.write_dword(I8080_WINDOW_REG_OFS, (dc << DC_BIT_OFFSET) | data)
  
async def i8080_read_trans(cfg_axil_master):
    rd = await cfg_axil_master.read_dword(I8080_WINDOW_REG_OFS)
    return rd

async def write_to_i8080_mem(cfg_axil_master, data=[], if_size):
    await i8080_write_trans(cfg_axil_master, I8080_CMD, MEM_WRITE_CMD)
    cur_data = 0
    if if_size==1:
      for i in data:
        await i8080_write_trans(cfg_axil_master, I8080_DATA, i)
    else:    
      for i in data:
        await i8080_write_trans(cfg_axil_master, I8080_DATA, ((i*2+1)<<8) | (i*2) )
        
async def read_from_i8080_mem(cfg_axil_master, size_in_bytes, if_size):
    rd = []
    await i8080_write_trans(cfg_axil_master, I8080_CMD, MEM_READ_CMD)
    for i in range(size_in_bytes):
      rd.append(await i8080_read_trans(cfg_axil_master))
    return rd
    
TEST_ARRAY_SIZE = 4


async def window_access_test(cfg_axil_master, test_array_sz, if_size):
    wr_arr = range(test_array_sz)
    await write_to_i8080_mem(cfg_axil_master, wr_arr, if_mode)
    rd_arr = await read_from_i8080_mem(cfg_axil_master, test_array_sz, if_mode)
    for i in range(test_array_sz):
      assert wr_arr[i] == rd_arr[i]
  
@cocotb.test()
async def i8080_ctrl_test(dut):
    cocotb.start_soon(Clock(dut.aclk, 10, units="ns").start())
    cocotb.start_soon(cycle_te(dut))

    dut.arstn.setimmediatevalue(0)

    """Reset!"""
    await cycle_reset(dut)

    cfg_axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut,""), dut.aclk, dut.arstn, False)
    await Timer(100, units="ns")

    rd = await cfg_axil_master.read_dword(0x0)
    print("i8080 version: %x" % rd)

#    await cfg_axil_master.write_dword(I8080_GONFIG_REG_0_OFS, 0x0)
#    await cfg_axil_master.write_dword(I8080_GONFIG_REG_0_OFS, 0x01010101)
    await cfg_axil_master.write_dword(I8080_GONFIG_REG_0_OFS, 0x02020202)
    
    print("Mode 8b")
    await cfg_axil_master.write_dword(I8080_GONFIG_REG_1_OFS, IF_MODE_8B)

# Выдача данных 
#    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, 0x2C00)
#    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, 0x1122 | (1<<30))


# Выдача данных через FIFO
#    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS,  2 | (3<<30))
#    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS,  8 | (2<<30))
#    await cfg_axil_master.write_dword(I8080_DATA_FIFO_OFS, 0x44332211)
#    await cfg_axil_master.write_dword(I8080_DATA_FIFO_OFS, 0x88776655)

    await Timer(200, units="ns")
#    for i in range(4):
#      await write_to_i8080_mem(cfg_axil_master, i)
    window_access_test(cfg_axil_master, TEST_ARRAY_SIZE)
#    rd = await cfg_axil_master.read_dword(I8080_WINDOW_REG_OFS)
#    print("Readed data: %x" % rd)

    await Timer(1, units="us")
    print("End of test")

