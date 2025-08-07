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
RSTN_BIT_OFS  =  4

I8080_WINDOW_REG_OFS          = 0x0C
DC_BIT_OFFSET = 31


I8080_CMD_FIFO_OFS            = 0x10
CMD_TYPE_OFFSET  = 30
WRITE_CMD     = 0 << CMD_TYPE_OFFSET
WRITE_PARAM   = 1 << CMD_TYPE_OFFSET
WRITE_N_PARAM = 2 << CMD_TYPE_OFFSET
SYNC_CMD      = 3 << CMD_TYPE_OFFSET


I8080_DATA_FIFO_OFS           = 0x14

I8080_CSN_REG_OFS             = 0x18
I8080_MEM_SELECT   = 0
I8080_MEM_DESELECT = 1

I8080_FIFO_STATUS_REG         = 0x1C
DATA_FIFO_EMPTY_MASK   = (1<<2)
TASK_FIFO_EMPTY_MASK   = 1



if_size_8B  = 1
if_size_16B = 2


MEM_WRITE_CMD = 0x1C
MEM_READ_CMD  = 0x1D

I8080_CMD  = 0
I8080_DATA = 1

TE_SYNC_FLG  = (2)
INT_SYNC_FLG = (1)

async def generate_te_strobe(dut):
    dut.TE.setimmediatevalue(1)
    await Timer(100, units="ns")
    dut.TE.setimmediatevalue(0)
    
async def wait_int_strobe(dut):
    await RisingEdge(dut.int_strb)  

################################################
#  Класс, управляющий работой контроллера
################################################

class i8080_ctrl_c:
  def __init__(self, dut, cfg_axil_master, if_size):
    self.cfg_axil_master = cfg_axil_master   # Номер используемого канала  
    self.if_size         = 0                 # Направление 
    self.dut             = dut               # Объект для доступа к пинам проверяемого устройства
    
  # Управляет сигналом CSn модели памяти дисплея i8080
  async def set_csn(self, sel):
    await Timer(100, units="ns")
    await self.cfg_axil_master.write_dword(I8080_CSN_REG_OFS, sel);
    await Timer(100, units="ns")

  # Выполяет одну транзакцию записи на шине i8080
  async def write_trans(self, dc, data):
    await self.cfg_axil_master.write_dword(I8080_WINDOW_REG_OFS, (dc << DC_BIT_OFFSET) | data)

  # Выполяет одну транзакцию чтения на шине i8080  
  async def read_trans(self):
    rd = await self.cfg_axil_master.read_dword(I8080_WINDOW_REG_OFS)
    return rd

  # Выдает на шину команду без параметров
  async def send_cmd(self, cmd):
    await self.cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, WRITE_CMD | cmd)

  # Выдает на шину команду с одним параметром
  async def send_cmd_with_param(self, cmd, param):
    await self.cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, WRITE_CMD | cmd)
    await self.cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, WRITE_PARAM | param)

  # Ожидает опустошения FIFO данных
  async def wait_data_fifo_empty(self):
    fifo_status=await self.cfg_axil_master.read_dword(I8080_FIFO_STATUS_REG)
    while (fifo_status &  DATA_FIFO_EMPTY_MASK) == 0:
      fifo_status = await self.cfg_axil_master.read_dword(I8080_FIFO_STATUS_REG)    
      
  # Ожидает опустошения FIFO команд
  async def wait_task_fifo_empty(self):
    fifo_status=await self.cfg_axil_master.read_dword(I8080_FIFO_STATUS_REG)
    while (fifo_status &  TASK_FIFO_EMPTY_MASK) == 0:
      fifo_status = await self.cfg_axil_master.read_dword(I8080_FIFO_STATUS_REG)      
      
  # Возвращает 1, когда FIFO заданий пустое
  async def is_task_fifo_empty(self):
    fifo_status=await self.cfg_axil_master.read_dword(I8080_FIFO_STATUS_REG)
    return 1 if (fifo_status & TASK_FIFO_EMPTY_MASK) != 0 else 0
        
  # Выдает на шину команду с несколькими параметрами
  async def send_cmd_with_n_params(self, cmd, params):
  #  print("send_cmd_with_n_params enter")
    await self.cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, WRITE_CMD | cmd)
    await self.cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, WRITE_N_PARAM | len(params))
    b = 0
    b_in_w = 0
    w = 0
    while(b<len(params)):
      w = (w>>8) | (params[b]<<24)
      b = b + 1
      b_in_w = b_in_w + 1
      if b_in_w == 4:
        b_in_w = 0
        await self.cfg_axil_master.write_dword(I8080_DATA_FIFO_OFS, w)
    if b_in_w != 0:  
      w = w >> (4-b_in_w)*8    
      await self.cfg_axil_master.write_dword(I8080_DATA_FIFO_OFS, w)
    
  # Пишет в FIFO заданий команду выполнения синхронизациии
  async def write_sync_to_task_fifo(self, sync_params):
    await self.cfg_axil_master.write_dword(I8080_CMD_FIFO_OFS, SYNC_CMD | sync_params)
   
   
##################################################################
#  Класс, содержащий окружение, необходимое тестовым функциям
##################################################################      

class env_c:
  def __init__(self, dut, if_size): 
    self.dut             = dut               
    self.i8080_ctrl      = None
    self.cfg_axil_master = None
    self.if_size         = if_size
    
  async def build(self):  
    cocotb.start_soon(Clock(self.dut.aclk, 10, units="ns").start())
    self.dut.TE.setimmediatevalue(0)
    self.dut.arstn.setimmediatevalue(0)

    self.dut.if_mode.setimmediatevalue(1 if self.if_size == if_size_16B else 0)

    await cycle_reset(self.dut)

    self.cfg_axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut,""), self.dut.aclk, self.dut.arstn, False)
    await Timer(100, units="ns")

    self.i8080_ctrl = i8080_ctrl_c(self.dut, self.cfg_axil_master, self.if_size) 

# Проверка версии
    rd = await self.cfg_axil_master.read_dword(0x0)
    print("i8080 version: %x" % rd)

# Запись конфигурации контроллера
    await self.cfg_axil_master.write_dword(I8080_GONFIG_REG_0_OFS, 0x02020202)
    await self.cfg_axil_master.write_dword(I8080_GONFIG_REG_1_OFS, self.if_size | (1<<RSTN_BIT_OFS))
            
  async def set_if_size(self, if_size):
    self.if_size             = if_size
    self.i8080_ctrl.if_size  = if_size
    self.dut.if_mode.setimmediatevalue(1 if if_size == if_size_16B else 0)
    await self.cfg_axil_master.write_dword(I8080_GONFIG_REG_1_OFS, self.if_size | (1<<RSTN_BIT_OFS))

       
# Записывает в модель памяти дисплея i8080 массив байт
async def write_to_i8080_mem(i8080_ctrl, data, if_size):
    await i8080_ctrl.set_csn(I8080_MEM_SELECT)
    await i8080_ctrl.write_trans(I8080_CMD, MEM_WRITE_CMD)
    cur_data = 0
    if if_size==1:
      for i in data:
        await i8080_ctrl.write_trans(I8080_DATA, i)
    else:    
      for i in range(len(data)//2):
        await i8080_ctrl.write_trans(I8080_DATA, (data[i*2+1]<<8) | (data[i*2]) )
    await i8080_ctrl.set_csn(I8080_MEM_DESELECT)


# Читает из модели памяти дисплея i8080 заданное число байт и возвращает их в виде списка
async def read_from_i8080_mem(i8080_ctrl, size_in_bytes, if_size):
    rd = []
    await i8080_ctrl.set_csn(I8080_MEM_SELECT)
    await i8080_ctrl.write_trans(I8080_CMD, MEM_READ_CMD)
    
    if if_size==1:
      for i in range(size_in_bytes):
        rd.append(await i8080_ctrl.read_trans())
    else:
      for i in range(size_in_bytes//2):
        rd_16b = await i8080_ctrl.read_trans()  
        rd.append(rd_16b & 0xff)
        rd.append(rd_16b >> 8)
        
    await i8080_ctrl.set_csn(I8080_MEM_DESELECT)
    return rd
    

# Выполняет тест памяти через окно на шину i8080
async def mem_test_thr_window(i8080_ctrl, test_array_sz, if_size):
    wr_arr = range(test_array_sz)
    await write_to_i8080_mem(i8080_ctrl, wr_arr, if_size)
    rd_arr = await read_from_i8080_mem(i8080_ctrl, test_array_sz, if_size)
    for i in range(test_array_sz // if_size):
      assert wr_arr[i] == rd_arr[i]

# Выполняет тест памяти с использованием режима FIFO
async def mem_test_thr_fifo(i8080_ctrl, test_array_sz=16, if_size=2, use_te=0, use_int=1):
    wr_arr = range(test_array_sz)
    await i8080_ctrl.set_csn(I8080_MEM_SELECT)
    if use_te==1:
      await i8080_ctrl.write_sync_to_task_fifo(TE_SYNC_FLG)
    
    await i8080_ctrl.send_cmd_with_n_params(MEM_WRITE_CMD, wr_arr)
    
    if use_te==1: 
      # Делаем задержку
      await Timer(1, units="us")
      # Проверяем что задания не выполнялись до получения строба TE
      task_fifo_empty = await i8080_ctrl.is_task_fifo_empty()
      assert task_fifo_empty==0
      await generate_te_strobe(i8080_ctrl.dut)
    
    if use_int==1:
      await i8080_ctrl.write_sync_to_task_fifo(INT_SYNC_FLG)
      await wait_int_strobe(i8080_ctrl.dut);
    else:
      await i8080_ctrl.write_sync_to_task_fifo(0)
      await i8080_ctrl.wait_task_fifo_empty()
      
    await i8080_ctrl.set_csn(I8080_MEM_DESELECT)
    
    rd_arr = await read_from_i8080_mem(i8080_ctrl, test_array_sz, if_size)
    for i in range(test_array_sz // if_size):
      assert wr_arr[i] == rd_arr[i]
      

    
    
    
# Тест памяти дисплея через окно на шину i8080
@cocotb.test()
async def i8080_mem_test_thr_win(dut):
    print("\n******** WINDOW TO BUS CHECK START ********\n")
    
    env = env_c(dut, if_size_16B)
    await env.build()
    await Timer(200, units="ns")
    
    if_sizes   = [1, 2]
    data_sizes = [1,2,3,4,5,8,13]

    test_params = list(itertools.product(data_sizes, if_sizes))

    for data_sz, if_sz in test_params:
      print("data_sz: %d if_sz: %d" % (data_sz, if_sz))
      await env.set_if_size(if_sz)
      await mem_test_thr_window(env.i8080_ctrl, data_sz, if_sz)
      await Timer(100, units="ns")
        
    await Timer(1, units="us")
    
    print("\n******** WINDOW TO BUS CHECK END ********\n")
    

# Тест памяти дисплея с использованием FIFO заданий
@cocotb.test()
async def i8080_mem_test(dut, if_size = if_size_16B,  test_array_sz=16, use_te=0, use_int = 1):    
    print("\n******** FIFO MODE CHECK START ********\n")
    
    env = env_c(dut, if_size)
    await env.build()
    await Timer(200, units="ns")
    
    use_te        = 0
    data_sz_lst   = [1,2,3,4,8,13,256]
    if_size_lst   = [1,2]
    use_int_lst   = [0,1]

    test_params = list(itertools.product(data_sz_lst, if_size_lst, use_int_lst))
    
    for data_sz, if_sz, use_int in test_params:
      print("data_sz: %d if_sz: %d use_int: %d" % (data_sz, if_sz, use_int))
      await env.set_if_size(if_sz)
      await mem_test_thr_fifo(env.i8080_ctrl, data_sz, if_sz, use_te, use_int)
      await Timer(100, units="ns")
      
      
    data_sz_lst   = [3,7,9]
    if_size_lst   = [1,2]
    use_int_lst   = [0,1]  
    use_te_lst    = [0,1]
    
    test_params = list(itertools.product(data_sz_lst, if_size_lst, use_int_lst, use_te_lst))
    
    for data_sz, if_sz, use_int, use_te in test_params:
      print("data_sz: %d if_sz: %d use_int: %d, use_te: %d" % (data_sz, if_sz, use_int, use_te))
      await env.set_if_size(if_sz)
      await mem_test_thr_fifo(env.i8080_ctrl, data_sz, if_sz, use_te, use_int)
      await Timer(100, units="ns")
            
    print("\n******** FIFO MODE CHECK END ********\n")

if cocotb.SIM_NAME:
    logging.getLogger('cocotb.lio_i8080_tb.').setLevel(logging.WARNING)
  



