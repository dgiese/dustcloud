cc = gcc
cflags = -O2 -pipe -Wall -g -ffunction-sections -fdata-sections
ldflags = -static -s -Wl,--gc-sections -Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now
build_dir = ./build

srcs = $(wildcard src/*.c)
objs = $(srcs:%.c=$(build_dir)/%.o)
deps = $(objs:%.o=%.d)
bin = dummycloud

all : $(bin)

$(bin) : $(build_dir)/$(bin)

$(build_dir)/$(bin) : $(objs)
	mkdir -p $(@D)
	$(cc) $(ldflags) $^ -o $@

-include $(deps)

$(build_dir)/%.o : %.c
	mkdir -p $(@D)
	$(cc) $(cflags) -MMD -c $< -o $@

.PHONY: clean

clean:
	$(RM) $(build_dir)/$(bin) $(objs) $(deps)
	$(RM) -r $(build_dir)
