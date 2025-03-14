# lio_i8080

## RU

Контроллер дисплея с интерфейсом i8080 для подсистемы ввода вывода Ленинград.

Характеристики контроллера:

* Интерфейс процессорной шины: AXI Lite 32 бита;
* Разрядность шины i8080: 8 и 16 бит;
* Наличие сигнала запроса DMA операции;
* Поддержка синхронизации записи в память с сигналом начала развертки от дисплея;
* Контроллер имеет 3 возможных режима работы:
  - Режим моста. В данном режиме контроллер преобразует транзакцию на AXI Lite в транзакцию на шине i8080;
  - Режим FIFO. В данном режиме контроллер считывает задания и данные из соответствующих FIFO; 
  - Режим DMA. С помощью внешнего DMA контроллера может быть организована подгрузка данных в соответствующее FIFO по генерируемому контроллером запросу.

## EN

Display controller with i8080 interface for Leningrad I/O subsystem.

Controller specifications:

* Processor bus interface: AXI Lite 32 bits;
* i8080 bus width: 8 and 16 bits;
* DMA operation request signal available;
* Support for memory write synchronization with display scan start signal;
* The controller has 3 possible operating modes:
- Bridge mode. In this mode the controller converts a transaction on AXI Lite into a transaction on the i8080 bus;
- FIFO mode. In this mode the controller reads tasks and data from the corresponding FIFOs;
- DMA mode. Using an external DMA controller, data loading into the corresponding FIFO can be organized based on a request generated by the controller.
