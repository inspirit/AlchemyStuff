package  
{
	import apparat.asm.__cint;
	import apparat.math.FastMath;
	import apparat.memory.Memory;
	import flash.display.StageAlign;
	import flash.filters.GlowFilter;

	import com.bit101.components.RadioButton;

	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.getTimer;
	import ru.inspirit.image.mem.MemImageUChar;
	import ru.inspirit.image.TemplateMatchFFT;

	/**
	 * ...
	 * @author Eugene Zatepyakin
	 */
	[SWF(width='1000',height='560',frameRate='25',backgroundColor='0xFFFFFF')]
	public final class TestTemplateMatch extends Sprite 
	{
		[Embed(source = '../assets/lena_512.jpg')] private static const img_ass:Class;
		
		public const GRAYSCALE_MATRIX:ColorMatrixFilter = new ColorMatrixFilter([
                        																0, 0, 0, 0, 0,
            																			0, 0, 0, 0, 0,
            																			.2989, .587, .114, 0, 0,
            																			0, 0, 0, 0, 0
																						]);
		public const ORIGIN:Point = new Point();
		
		public var ram:ByteArray;
		public var tm:TemplateMatchFFT = new TemplateMatchFFT();
		
		public var imgU:MemImageUChar;
		public var tmplU:MemImageUChar;
		
		public var imgB:Bitmap;
		public var tB:Bitmap;
		public var rB:Bitmap;
        public var drawSh:Shape;
		
		public var resultPtr:int;
		
		public const scl:Number = 2;
		
		public var _txt:TextField;
		
		public function TestTemplateMatch() 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		protected function init(e:Event = null):void
		{
			initStage();
			
			imgB = Bitmap(new img_ass);
			var imgBmp:BitmapData = imgB.bitmapData;
			
			var iw:int = imgBmp.width;
			var ih:int = imgBmp.height;
			//var tw:int = 9;
			//var th:int = 11;
			var tw:int = 20*scl;//20 + Math.random() * (iw * 0.125);
			var th:int = 20*scl;//20 + Math.random() * (ih * 0.125);
			
			var tmplBmp:BitmapData = new BitmapData(tw, th, false, 0x0);
			
			imgU = new MemImageUChar();
			tmplU = new MemImageUChar();
			
			var tmChunk:int = tm.calcRequiredChunkSize(iw + tw, ih + th);
			var iChunk:int = imgU.calcRequiredChunkSize(iw, ih);
			var tChunk:int = tmplU.calcRequiredChunkSize(tw, th);
			
			ram = new ByteArray();
			ram.endian = Endian.LITTLE_ENDIAN;
			ram.length = 1024 + tmChunk + iChunk + tChunk + ((iChunk << 3));
			
			Memory.select(ram);
			
			var offset:int = 1024;
			tm.setup(offset, iw + tw, ih + th);
			offset += tmChunk;
			imgU.setup(offset, iw, ih);
			offset += iChunk;
			tmplU.setup(offset, tw, th);
			offset += tChunk;
			
			resultPtr = offset;
			
			tB = new Bitmap(tmplBmp);
			tB.filters = [new GlowFilter(0x000000, 0.5, 8, 8, 2, 2)];
			//tB.x = imgB.width;
			
			rB = new Bitmap(new BitmapData(iw - tw + 1, ih - th + 1, false, 0x0) );
			rB.x = imgB.width;
			
			addChild(imgB);
			addChild(tB);
			addChild(rB);
			
			var gi:BitmapData = new BitmapData(iw, ih, false, 0x0);
			gi.applyFilter(imgBmp, imgBmp.rect, ORIGIN, GRAYSCALE_MATRIX);
			
			imgU.fill(gi.getVector(new Rectangle(0,0,iw, ih)));
			
			_txt = new TextField();
			_txt.width = 200;
			_txt.multiline = true;
			_txt.autoSize = 'left';
			_txt.x = 400;
			_txt.y = imgB.height + 5;
			
			addChild(_txt);

			var cntx:int = 20;
			var cnty:int = imgB.height + 10;
			var stp:int = 120;
            new RadioButton(this, cntx, cnty, 'CCORR', false, onMethodChanged);
            new RadioButton(this, cntx, cnty+20, 'CCORR_NORMED', true, onMethodChanged);
            new RadioButton(this, cntx+stp, cnty, 'CCOEFF', false, onMethodChanged);
            new RadioButton(this, cntx+stp, cnty+20, 'CCOEFF_NORMED', false, onMethodChanged);
            new RadioButton(this, cntx+stp*2, cnty, 'SQDIFF', false, onMethodChanged);
            new RadioButton(this, cntx+stp*2, cnty+20, 'SQDIFF_NORMED', false, onMethodChanged);

            drawSh = new Shape();
            addChild(drawSh);

            methodID = 1,
            runTest();
		}

        public var methodID:int = 0;
        private function onMethodChanged(e:Event):void
        {
            var rd:RadioButton = e.currentTarget as RadioButton;
            var nm:String = rd.label;
            if(nm == 'CCORR') methodID = 0;
            if(nm == 'CCORR_NORMED') methodID = 1;
            if(nm == 'CCOEFF') methodID = 2;
            if(nm == 'CCOEFF_NORMED') methodID = 3;
            if(nm == 'SQDIFF') methodID = 4;
            if(nm == 'SQDIFF_NORMED') methodID = 5;

            runTest();
        }
		
		private function runTest(e:MouseEvent = null):void
		{
			var iw:int = imgB.width;
			var ih:int = imgB.height;
			var tw:int = tB.width;
			var th:int = tB.height;
			
			//var tx:int = 138;//124;
			//var ty:int = 25;//124;
			var tx:int = 124*scl;
			var ty:int = 124*scl;
			tB.bitmapData.copyPixels(imgB.bitmapData, new Rectangle(tx, ty, tw, th), ORIGIN);
			
			tB.bitmapData.applyFilter(tB.bitmapData, tB.bitmapData.rect, ORIGIN, GRAYSCALE_MATRIX);
			tmplU.fill(tB.bitmapData.getVector(tB.bitmapData.rect));

            tB.bitmapData.copyPixels(imgB.bitmapData, new Rectangle(tx, ty, tw, th), ORIGIN);
			
			var tt:int = getTimer();
			tm.match8u(imgU.ptr, iw, ih, tmplU.ptr, tw, th, resultPtr, methodID);
			tt = getTimer() - tt;
			
			var res_w:int = iw - tw + 1;
			var res_h:int = ih - th + 1;
			var res_s:int = res_h * res_w;
			var i:int, j:int;
			var ptr0:int;
			var maxval:Number = Number.MIN_VALUE;
            var minval:Number = Number.MAX_VALUE;
            var val:Number;
			var best_x:int = -1;
			var best_y:int = -1;

            i = 0;
			ptr0 = resultPtr;
			while (i < res_s)
			{
				val = Memory.readDouble(ptr0);
                if(val < minval)
                {
                    minval = val;
                    if(methodID > 3)
                    {
                        best_x = i % res_w;
                        best_y = i / res_w;
                    }
                }
                if(val > maxval)
                {
                    maxval = val;
                    if(methodID < 4)
                    {
                        best_x = i % res_w;
                        best_y = i / res_w;
                    }
                }

				ptr0 = __cint(ptr0 + 8);
				++i;
			}

            _txt.text = 'tmatch process: ' + tt + 'ms\nmin/max response: ' + [minval, maxval];

            drawSh.graphics.clear();
            drawSh.graphics.lineStyle(1, 0x00FF00);
            drawSh.graphics.drawRect(best_x, best_y, tw,  th);
			
			var resData:Vector.<uint> = new Vector.<uint>(res_s, true);
			var c:int;
			i = 0;
			ptr0 = resultPtr;
            maxval -= minval;
			while (i < res_s)
			{
				val = Memory.readDouble(ptr0);
				c = (  ((val - minval) / maxval) ) * 0xFF;
				/*if (val < maxval*0.9)
				{
					c = 0;
				}
				else {
					c = val * 0xff;
				}*/
				resData[i] = c << 16 | c << 8 | c;
				
				ptr0 = __cint(ptr0 + 8);
				++i;
			}
			
			//throw new Error('sizes: ' + [res_w, res_h, rB.width, rB.height]);
			rB.bitmapData.setVector(rB.bitmapData.rect, resData);
			//rB.alpha = 0.5;
			//rB.y = 0;
			//var thresh:int = 0x00 << 16 | 0x00 << 8 | ();
			//rB.bitmapData.threshold(rB.bitmapData, rB.bitmapData.rect, ORIGIN, '<', thresh, 0x00, 0x0000FF);
		}
		
		protected function initStage():void
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;

			var myContextMenu:ContextMenu = new ContextMenu();
			myContextMenu.hideBuiltInItems();

			var copyr:ContextMenuItem;
			copyr = new ContextMenuItem("© inspirit.ru", false, false);
			myContextMenu.customItems.push(copyr);

			contextMenu = myContextMenu;
		}
		
	}

}