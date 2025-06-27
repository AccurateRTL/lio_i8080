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

async def cycle_te(dut):
  while(1):
    dut.TE.setimmediatevalue(0)
    await Timer(1000, units="ns")
    dut.TE.setimmediatevalue(1)
    await Timer(100, units="ns")

IF_MODE_8B  = 1
IF_MODE_16B = 2

@cocotb.test()
async def my_first_test(dut):
    """Hello!"""
    """Try accessing the design!"""
    cocotb.start_soon(Clock(dut.aclk, 10, units="ns").start())
    cocotb.start_soon(cycle_te(dut))

    dut.aclk.setimmediatevalue(0)
    dut.arstn.setimmediatevalue(0)
    dut.DI.setimmediatevalue(0x1234)

    """Reset!"""
    await cycle_reset(dut)

    cfg_axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut,""), dut.aclk, dut.arstn, False)
    #axi_ram.write(0x100, 10)
    await Timer(100, units="ns")

    rd = await cfg_axil_master.read_dword(0x0)
    print("i8080 version: %x" % rd)

#    await cfg_axil_master.write_dword(I8080_GONFIG_REG_0_OFS, 0x0)
#    await cfg_axil_master.write_dword(I8080_GONFIG_REG_0_OFS, 0x01010101)
    await cfg_axil_master.write_dword(I8080_GONFIG_REG_0_OFS, 0x02020202)
    
    print("Mode 8b")
    await cfg_axil_master.write_dword(I8080_GONFIG_REG_1_OFS, IF_MODE_16B)

# Задание цветового режима 16 бит
#    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, 0x3A00)
#    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, 0x6 | (1<<30))

# Выдача данных 
#    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, 0x2C00)
#    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, 0x1122 | (1<<30))


# Выдача данных через FIFO
    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS,  2 | (3<<30))
    await cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS,  8 | (2<<30))
    await cfg_axil_master.write_dword(I8080_DATA_FIFO_OFS, 0x44332211)
    await cfg_axil_master.write_dword(I8080_DATA_FIFO_OFS, 0x88776655)

    await Timer(200, units="ns")
    rd = await cfg_axil_master.read_dword(I8080_WINDOW_REG_OFS)
    print("Readed data: %x" % rd)

    await Timer(1, units="us")
    print("End of test")

