
all:clean
	nasm -I include -o mbr.bin mbr.s
	nasm -I include -o loader.bin loader.s 
	dd if=/dev/zero of=c.img count=10000
	dd if=mbr.bin of=c.img bs=512 count=1 conv=notrunc
	dd if=loader.bin of=c.img bs=512 count=4 seek=2 conv=notrunc
	dd if=kernel/kernel.bin of=c.img bs=512 count=200 seek=9 conv=notrunc

clean:
	rm -f bochsout.txt
	rm -f mbr.bin
	rm -f loader.bin
	rm -f c.img