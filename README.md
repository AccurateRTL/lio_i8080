# lio_i8080

[To english version](#en_version)

## Описание

Данное IP входит в состав подсистемы ввода-вывода Ленинград и может включать в себя другие IP из данной библиотеки, поэтому перед использованием данного устройства следует либо получить все необходимые зависимости, либо убедиться в их отсутствии. Подробнее о подсистеме Ленинград и используемом в ней подходе к управлению зависимостями, качеством и использовании IP можно узнать из ее [документации](https://github.com/AccurateRTL/leningradio). 

## Документация

[Руководство пользователя](doc/user_guide_ru.md)

## Предварительные условия для запуска тестов

1. Для запуска тестов должны быть установлены следующие инструменты: [fusesoc](https://github.com/olofk/fusesoc), [cocotb](https://www.cocotb.org/), [verilator](https://www.veripool.org/verilator) и/или [icarus](https://github.com/steveicarus/iverilog).
2. В тестах используются verification ip из пакета cocotbext.   
3. Запуск тестов должен выполняться из корневого каталога IP.
4. Все зависимые ядра должны быть размещены в одном каталоге с данным IP.

## Проверка RTL кода ядра

1. Для проверки качества IP ядра осуществляется с помощью выполнения следующих задач: симуляция с анализом покрытия кода, статический анализ, методологический анализ, пробный синтез и т.п.
2. Для выполнения любой из этих задач используется утилита make, вызывающая программу fusesoc с соответствующими параметрами. Данная программа осуществляет генерацию инфраструктуры и скриптов, необходимых для запуска данного инструмента и выполняет с его помощью запрошенную задачу. Цели, соотвествующие задачам, и команды необходимые для их выполнения определены в Makefile, находящемся в корне файловой структуры IP. 
3. Результаты помещаются в отдельный каталог внутри создаваемого каталога build в корне файловой структуры IP.  

## Запуск тестов IP на симуляторе icarus

Моделирование с помощью icarus часто выполняется быстрее за счет меньшего времени компиляции. 

Запуск моделирования:

```  
make sim_icar
```

Временные диаграммы будут записаны в файле build/lio_i8080_0/sim_iverilog/dump.fst 

## Запуск тестов IP на симуляторе verilator

В помощью verilator могут быть получены не только лог моделирования и временные диаграммы, но и отчеты о покрытии кода IP ядра тестами.

Запуск моделирования:

```
make sim_veril
```

Временные диаграммы будут записаны в файл build/lio_i8080_0/sim_verilator/dump.fst

Отчеты о покрытии кода буду сохранены в каталоге build/lio_i8080_0/sim_verilator/coverage_reports

## Статический анализ кода verilator

```
make lint_veril
```

## Статический анализ кода verible

```
make lint_verib
```

## Удаление результатов моделирования, статического анализа и т.п.

```
make clean
```

# <a id="en_version">lio_i8080</a> 

## Description

This IP is part of the Leningrad I/O subsystem and may include other IPs from this library, so you should obtain all required dependencies before using this device. For more information about the Leningrad subsystem and its approach to dependency management, quality management, IP usage please refer to its documentation. 

## Documentation

[User Guide](doc/user_guide_en.md)

## Prerequisites for running tests

1. The following tools must be installed to run the tests: [fusesoc](https://github.com/olofk/fusesoc), [cocotb](https://www.cocotb.org/), [verilator](https://www.veripool.org/verilator) and/or [icarus](https://github.com/steveicarus/iverilog).
2. The tests use verification ip from the cocotbext package.   
3. Tests must be run from the root directory of the IP.
4. All dependent IP must be placed in the same directory as this IP.

## Verification of IP

1. Verification of IP quality is done by performing the following tasks: simulation with code coverage analysis, static analysis, methodological analysis, trial synthesis, etc.
2. To perform any of these tasks make utility is used. It calls the fusesoc program with the appropriate parameters. This program generates the infrastructure and scripts necessary to run the EDA tool and performs the requested task with it. The targets corresponding to the tasks and the commands needed to execute them are defined in the Makefile located at the root of the IP file structure. 
3. The results are placed in a separate directory inside the build directory created in the root of the IP file structure.  

## Running IP tests with icarus

Simulations with icarus are often faster due to the shorter compilation time. 

Running the simulation:

```  
make sim_icar
```

Waveforms will be written to the file build/lio_i8080_0/sim_iverilog/dump.fst.

## Running IP tests with verilator

With verilator not only simulation logs and timing diagrams can be obtained, but also reports about IP code coverage.

Running the simulation:

```
make sim_veril
```

The timing diagrams will be written to the file build/lio_i8080_0/sim_verilator/dump.fst

Code coverage reports will be saved in build/lio_i8080_0/sim_verilator/coverage_reports

## Static verilator code analysis

```
make lint_veril
```

## Static code analysis verible

```
make lint_verib
```

## Deleting the results of simulation, static analysis, etc.

```
make clean
```



