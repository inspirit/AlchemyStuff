package ru.inspirit.image.mem
{
	import apparat.asm.__asm;
	import apparat.asm.__cint;
	import apparat.asm.IncLocalInt;
	import apparat.math.IntMath;
	import apparat.memory.Memory;

	import flash.display.BitmapData;
	import flash.geom.Rectangle;
	/**
	 * @author Eugene Zatepyakin
	 */
	public final class MemImageInt
	{
		public var ptr:int;
		public var width:int;
		public var height:int;
		public var size:int;
		
		public var memoryChunkSize:int = 0;
		
		public function calcRequiredChunkSize(width:int, height:int):int
		{
			var size:int = (width * height) << 2;
			return IntMath.nextPow2(size);
		}
		
		public function setup(memOffset:int, width:int, height:int):void
		{
			this.width = width;
			this.height = height;
			this.size = width * height;

			ptr = memOffset;
			
			memoryChunkSize = calcRequiredChunkSize(width, height);
		}
		
		public function render(bmp:BitmapData, scale:int = 1):void
		{
			var w:int = IntMath.min(bmp.width, width);
			var h:int = IntMath.min(bmp.height, height);
			var area:int = w * h;
			var vec:Vector.<uint> = new Vector.<uint>( area );
			var _p:int = ptr;
			for(var i:int = 0; i < area; ++i)
			{
				vec[i] = __cint(Memory.readInt(_p) * scale);
				_p = __cint(_p + 4);
			}
			bmp.lock();
			bmp.setVector(new Rectangle(0, 0, w, h), vec);
			bmp.unlock();
		}
		
		public function renderAsFloat(bmp:BitmapData):void
		{
			var w:int = IntMath.min(bmp.width, width);
			var h:int = IntMath.min(bmp.height, height);
			var area:int = w * h;
			var vec:Vector.<uint> = new Vector.<uint>( area );
			var _p:int = ptr;
			for(var i:int = 0; i < area; ++i)
			{
				var c:int = Memory.readFloat(_p) * 0xFF;
				c = Math.sqrt(c*c);
				vec[i] = c << 16 | c << 8 | c;
				_p = __cint(_p + 4);
			}
			bmp.lock();
			bmp.setVector(new Rectangle(0, 0, w, h), vec);
			bmp.unlock();
		}
		
		public function fill(img:Vector.<uint>):void
		{
			var _ptr:int = ptr;
			MemImageMacro.fillIntBuffer(_ptr, img);
		}
		
		public function grayscale(dst:int):void
		{
			var _ptr:int = ptr;
			var end:int = __cint(_ptr + (size << 2));
			while (_ptr < end)
			{
				var c:int = Memory.readInt(_ptr);
				Memory.writeByte(
								__cint(( 77*(c>>16&0xFF) + 150*(c>>8&0xFF) + 29*(c&0xFF) ) >> 8),
								dst
								);
				_ptr = __cint(_ptr + 4);
				__asm(IncLocalInt(dst));
			}
		}
	}
}
