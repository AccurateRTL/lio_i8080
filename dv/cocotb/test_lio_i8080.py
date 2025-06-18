# Copyright AccurateRTL contributors.
# Licensed under the MIT License, see LICENSE for details.
# SPDX-License-Identifier: MIT

import logging
import random
import math
import itertools
import cocotb
import os

import cocotb_test.simulator
import pytest

from cocotb.triggers import FallingEdge, RisingEdge, Timer, Event
from cocotb.regression import TestFactory
from cocotb.clock import Clock
from cocotbext.axi import AxiBus, AxiMaster, AxiRam

async def cycle_reset(dut):
    dut.arstn.setimmediatevalue(0)
    for i in range(10):
        await RisingEdge(dut.aclk)
    dut.arstn.setimmediatevalue(1)
    
def cycle_pause():
    return itertools.cycle([1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0])

def random_pause():
    l = [1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0]
    random.shuffle(l)
    return itertools.cycle(l)    
    
def set_idle_generator(axi_master, axi_ram, generator=None):
    if generator:
      axi_master.write_if.aw_channel.set_pause_generator(generator())
      axi_master.write_if.w_channel.set_pause_generator(generator())
      axi_master.read_if.ar_channel.set_pause_generator(generator())
      axi_ram.write_if.b_channel.set_pause_generator(generator())
      axi_ram.read_if.r_channel.set_pause_generator(generator())
      
def set_backpressure_generator(axi_master, axi_ram, generator=None):
    if generator:
      axi_master.write_if.b_channel.set_pause_generator(generator())
      axi_master.read_if.r_channel.set_pause_generator(generator())
      
      axi_ram.write_if.aw_channel.set_pause_generator(generator())
      axi_ram.write_if.w_channel.set_pause_generator(generator())
      axi_ram.read_if.ar_channel.set_pause_generator(generator())
      
      
async def test(dut, idle_gen, bpres_gen):
    """Try accessing the design!"""
    dut.arstn.setimmediatevalue(0)
    
    cocotb.start_soon(Clock(dut.aclk, 10, units="ns").start())

    await cycle_reset(dut)

#    axi_ram    = AxiRam(AxiBus.from_prefix(dut, "axim"), dut.axim_aclk, dut.axim_arstn, reset_active_level=False, size=2**18)
#    axi_master = AxiMaster(AxiBus.from_prefix(dut,"axis"), dut.axis_aclk, dut.axis_arstn, False)
   
#    set_idle_generator(axi_master, axi_ram, idle_gen)  
#    set_backpressure_generator(axi_master, axi_ram, bpres_gen) 

    await Timer(100, units="ns")
    
#    for i in range(32):
#      await axi_master.write_dword(i*4, i)
    
#    for i in range(32):
#      rd = await axi_master.read_dword(i*4)
#      print("RD DATA: %x" % rd)
#      assert rd == i
      
#    await Timer(10, units="us")
#    print("End of timer 2")


if cocotb.SIM_NAME:
    #logging.getLogger('cocotb.lio_dma4fifo.axim').setLevel(logging.WARNING)
    #logging.getLogger('cocotb.lio_dma4fifo.axilm').setLevel(logging.WARNING)
    #logging.getLogger('cocotb.lio_dma4fifo.cfg').setLevel(logging.WARNING)

# Проверяем работоспособность всех каналов при различных длинах транзакций
    for test in [test]:
        factory = TestFactory(test)
        factory.add_option("idle_gen", [random_pause, None, cycle_pause])
        factory.add_option("bpres_gen", [None, cycle_pause, random_pause])
        factory.generate_tests()
