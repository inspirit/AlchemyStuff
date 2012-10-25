package demo
{
	import apparat.asm.__cint;
	import apparat.memory.Memory;
	import com.bit101.components.HRangeSlider;
	import com.bit101.components.Label;
	import com.bit101.components.RadioButton;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.filters.BlurFilter;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.text.TextField;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.getTimer;
	import ru.inspirit.image.edges.CannyEdgeDetector;
	import ru.inspirit.image.edges.FreiChenEdgeDetector;
	import ru.inspirit.image.edges.SobelEdgeDetector;
	import ru.inspirit.image.mem.MemImageInt;
	import ru.inspirit.image.mem.MemImageUChar;




	/**
	 * @author Eugene Zatepyakin
	 */
	[SWF(width='640',height='290',frameRate='25',backgroundColor='0xFFFFFF')]
	public final class DemoEdges extends Sprite
	{
		public static const GRAYSCALE_MATRIX:ColorMatrixFilter = new ColorMatrixFilter([
                        																.2989, .587, .114, 0, 0,
            																			.2989, .587, .114, 0, 0,
            																			.2989, .587, .114, 0, 0,
            																			0, 0, 0, 0, 0
																						]);
		public const ORIGIN:Point = new Point();
		public const blur2x2:BlurFilter = new BlurFilter(2,2,2);
		
		public const ram:ByteArray = new ByteArray();
		
		public var imgPtr:int;
		public var dxPtr:int;
		public var dyPtr:int;
		public var edgPtr:int;
		public var orPtr:int;
		public var histPtr:int;
		
		public var imgU:MemImageUChar = new MemImageUChar();
		public var imgI:MemImageInt = new MemImageInt();
		
		public var canny:CannyEdgeDetector;
		public var sobel:SobelEdgeDetector;
		public var fcd:FreiChenEdgeDetector;
		
		public var cannyPtr:int;
		
		protected var camBmp:Bitmap;
		protected var edgBmp:Bitmap;
        
        protected var _cam:Camera;
        protected var _video:Video;
        protected var _cambuff:BitmapData;
        protected var _cambuff_rect:Rectangle;
		protected var _cam_mtx:Matrix;
		
		protected var _txt:TextField;
		protected var _lab:Label;
		
		protected var edgeMethod:int = 0;
		
		protected var maxGrad:int = 32;
		
		public var edg_t_n:int = 0;
		public var edg_t:int = 0;
		public var edg_t_prev:int = 0;
		
		public function DemoEdges()
		{
			if(stage)
				init();
			else
				addEventListener( Event.ADDED_TO_STAGE, init );
		}
		
		protected function init( e:Event = null ):void
		{
			removeEventListener( Event.ADDED_TO_STAGE, init );
			//
			stage.scaleMode = StageScaleMode.NO_SCALE;
			var myContextMenu:ContextMenu = new ContextMenu();
			myContextMenu.hideBuiltInItems();
			var copyr:ContextMenuItem = new ContextMenuItem("© inspirit.ru", true, false);
			myContextMenu.customItems.push(copyr);			
			contextMenu = myContextMenu;
			//
			canny = new CannyEdgeDetector();
            sobel = new SobelEdgeDetector();
            fcd = new FreiChenEdgeDetector();
            //
			// web camera initiation
            initCamera(320, 240, 25);
            camBmp = new Bitmap(_cambuff.clone());
            edgBmp = new Bitmap(_cambuff.clone());
            edgBmp.x = camBmp.width;
            addChild(camBmp);
            addChild(edgBmp);
            //
            // debug text field
			_lab = new Label(this, 10, 242, '');
			var rd0:RadioButton = new RadioButton(this, 12, 263, 'CANNY', true, onCannyRad);
			rd0 = new RadioButton(this, 70, 263, 'SOBEL', false, onSobelRad);
			rd0 = new RadioButton(this, 128, 263, 'FREI CHEN', false, onFChRad);
			var lb:Label = new Label(this, 320, 242, 'CANNY THRESHOLD');
			var sl:HRangeSlider = new HRangeSlider(this, 320, 260, onCannyThresh);
			sl.width = 140;
			sl.minimum = 0.1;
			sl.maximum = 1.0;
			sl.lowValue = 0.2;
			sl.highValue = 0.85;
			sl.tick = 0.01;
			sl.labelPrecision = 2;
			sl.labelPosition = 'bottom';
            //
            var w:int = 320;
            var h:int = 240;
            var sz:int = (w * h);
            
            var cannyChunk:int = canny.calcRequiredChunkSize(w, h);
            
            ram.endian = Endian.LITTLE_ENDIAN;
			ram.length = 1024 + cannyChunk + sz + (sz<<2);
			ram.position = 0;
			Memory.select(ram);
			
			imgPtr = 1024;
			edgPtr = imgPtr + sz;
			cannyPtr = edgPtr + (sz << 2);
			
			imgU.setup(imgPtr, w, h);
			imgI.setup(edgPtr, w, h);
			
			canny.setup(cannyPtr, w, h);
			canny.lowThreshold = 0.2 * maxGrad;
			canny.highThreshold = 0.85 * maxGrad;
			
			sobel.setup(cannyPtr, w, h);
			
			addEventListener(Event.ENTER_FRAME, render);
		}
		
		protected function render(e:Event):void
		{
			_cambuff.draw( _video, _cam_mtx );
			camBmp.bitmapData.copyPixels(_cambuff, _cambuff_rect, ORIGIN);
			
			_cambuff.applyFilter(_cambuff, _cambuff_rect, ORIGIN, GRAYSCALE_MATRIX);
			
			var t:int = getTimer();
			
			var uptr:int = imgU.ptr;
			var iptr:int = imgI.ptr;
			var w:int = 320;
			var h:int = 240;
			var area:int = w * h;
			var data:Vector.<uint>;
			
			if(edgeMethod == 0)
			{
				//_cambuff.applyFilter( _cambuff, _cambuff_rect, ORIGIN, blur2x2);
				data = _cambuff.getVector(_cambuff_rect);
				imgU.fill(data);
				imgU.equalizeHist(iptr);
				//
				//canny.detect(uptr, iptr, w, h);
				canny.detect2(uptr, iptr, w, h);
			} else if(edgeMethod == 1){
				data = _cambuff.getVector(_cambuff_rect);
				imgU.fill(data);
				imgU.equalizeHist(iptr);
				sobel.detect(uptr, iptr, w, h, 2);
			}
			else if(edgeMethod == 2){
				data = _cambuff.getVector(_cambuff_rect);
				imgU.fill(data);
				fcd.detect(uptr, iptr, w, h);
			}
			
			edg_t = __cint( edg_t + (getTimer() - t) );
			if (++edg_t_n == 10)
			{
				edg_t_prev = edg_t / edg_t_n + 0.5;
				edg_t = edg_t_n = 0;
			}
			_lab.text = 'EDGE DETECTION: ' + edg_t_prev + 'ms';
			
			var bmp:BitmapData = edgBmp.bitmapData;
			for(var i:int = 0; i < area; ++i)
			{
				var c:uint = Memory.readInt(iptr);
				data[i] = c << 16 | c << 8 | c;
				iptr += 4;
			}
			
			bmp.lock();
			bmp.setVector(_cambuff_rect, data);
			bmp.unlock();
		}
		
		protected function onCannyRad(e:Event):void
		{
			edgeMethod = 0;
		}
		protected function onSobelRad(e:Event):void
		{
			edgeMethod = 1;
		}
		protected function onFChRad(e:Event):void
		{
			edgeMethod = 2;
		}
		
		protected function onCannyThresh(e:Event):void
		{
			var sl:HRangeSlider = HRangeSlider(e.currentTarget);
			canny.lowThreshold = sl.lowValue * maxGrad;
			canny.highThreshold = sl.highValue * maxGrad;
		}
		
		protected function initCamera(w:int = 640, h:int = 480, fps:int = 25):void
        {
            _cambuff = new BitmapData( w, h, false, 0x0 );
            _cam = Camera.getCamera();
            _cam.setMode( w, h, fps, true );

			_cambuff_rect = _cambuff.rect;
			_cam_mtx = new Matrix(-1, 0, 0, 1, w);
            
            _video = new Video( _cam.width, _cam.height );
            _video.attachCamera( _cam );
        }
	}
}
