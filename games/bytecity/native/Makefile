CXX ?= c++
CXXFLAGS ?= -std=c++17 -O3 -fPIC -Wall -Wno-unused-variable -Wno-unused-function

ENGINE_SRC = ../../../references/MicropolisCore/packages/micropolis-engine/src
INCLUDES = -I$(ENGINE_SRC) -I.

UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
  TARGET = libmicropolis.dylib
  SHARED_FLAGS = -dynamiclib -install_name @rpath/libmicropolis.dylib
else
  TARGET = libmicropolis.so
  SHARED_FLAGS = -shared
endif

SOURCES = \
  $(ENGINE_SRC)/allocate.cpp \
  $(ENGINE_SRC)/animate.cpp \
  $(ENGINE_SRC)/budget.cpp \
  $(ENGINE_SRC)/connect.cpp \
  $(ENGINE_SRC)/disasters.cpp \
  $(ENGINE_SRC)/evaluate.cpp \
  $(ENGINE_SRC)/fileio.cpp \
  $(ENGINE_SRC)/frontendmessage.cpp \
  $(ENGINE_SRC)/generate.cpp \
  $(ENGINE_SRC)/graph.cpp \
  $(ENGINE_SRC)/initialize.cpp \
  $(ENGINE_SRC)/map.cpp \
  $(ENGINE_SRC)/message.cpp \
  $(ENGINE_SRC)/micropolis.cpp \
  $(ENGINE_SRC)/position.cpp \
  $(ENGINE_SRC)/power.cpp \
  $(ENGINE_SRC)/random.cpp \
  $(ENGINE_SRC)/scan.cpp \
  $(ENGINE_SRC)/simulate.cpp \
  $(ENGINE_SRC)/sprite.cpp \
  $(ENGINE_SRC)/tool.cpp \
  $(ENGINE_SRC)/traffic.cpp \
  $(ENGINE_SRC)/update.cpp \
  $(ENGINE_SRC)/utilities.cpp \
  $(ENGINE_SRC)/zone.cpp \
  micropolis_c_api.cpp

OBJECTS = $(SOURCES:.cpp=.o)

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CXX) $(SHARED_FLAGS) $(OBJECTS) -o $@

%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(TARGET) *.o $(ENGINE_SRC)/*.o

.PHONY: all clean
