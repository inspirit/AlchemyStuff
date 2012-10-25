package
{
	import apparat.math.IntMath;
	import apparat.memory.Memory;
	import com.bit101.components.HUISlider;
	import com.bit101.components.Label;
	import com.bit101.components.Panel;
	import com.bit101.components.Style;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.getTimer;
	import nochump.util.zip.ZipEntry;
	import nochump.util.zip.ZipFile;
	import ru.inspirit.haar.HaarCascadesDetector;
	import ru.inspirit.image.edges.SobelEdgeDetector;
	import ru.inspirit.image.mem.MemImageInt;
	import ru.inspirit.image.mem.MemImageUChar;

	/**
	 * @author Eugene Zatepyakin
	 */
	
	[SWF(width='640',height='480',frameRate='30',backgroundColor='0xFFFFFF')]
	
	public final class DemoFaceDetect extends Sprite
	{
		public static const XML_FACE_URL:String = 'haarcascade_frontalface_default.xml';
		public static const XML_MOUTH_URL:String = 'haarcascade_mcs_mouth.xml';
		public static const XML_L_EYE_URL:String = 'haarcascade_mcs_lefteye.xml';
		public static const XML_R_EYE_URL:String = 'haarcascade_mcs_righteye.xml';
		
		public static const ZIP_XML_URL:String = 'cascades_face.zip';
		
		public static const GRAYSCALE_MATRIX:ColorMatrixFilter = new ColorMatrixFilter([
			.2989, .587, .114, 0, 0,
            .2989, .587, .114, 0, 0,
            .2989, .587, .114, 0, 0,
            0, 0, 0, 0, 0
		]);
		
		public static const ORIGIN:Point = new Point();
		
		public var imageRect:Rectangle;
		
		public var baseScale:Number = 2.0;
		public var scaleIncrement:Number = 1.25;
		public var stepIncrement:Number = 0.05;
		public var edgeDensity:Number = 0.01;//0.09;
        
        private var view :Sprite;
		private var faceRectContainer :Sprite;
		protected var camBmp:Bitmap;
		protected var _cam:Camera;
        protected var _video:Video;
        protected var _cambuff:BitmapData;
        protected var _cambuff_rect:Rectangle;
        protected var _cam_mtx:Matrix;
		private var detectionMap:BitmapData;
		private var detectionMapOrig:BitmapData;
		private var drawMatrix:Matrix;
		private var scaleFactor:Number = 2;
		private var w:int = 640;
		private var h:int = 480;
        
        public const detector:HaarCascadesDetector = new HaarCascadesDetector();
        public const detectorLE:HaarCascadesDetector = new HaarCascadesDetector();
        public const detectorRE:HaarCascadesDetector = new HaarCascadesDetector();
        public const detectorM:HaarCascadesDetector = new HaarCascadesDetector();
        public const ram:ByteArray = new ByteArray();
        
        public const sobel:SobelEdgeDetector = new SobelEdgeDetector();
        public var edgesPtr:int;
        public var imgPtr:int;
        public var detectorPtr:int;
        
        public var imgU:MemImageUChar = new MemImageUChar();
		public var imgI:MemImageInt = new MemImageInt();
        
        protected var _timer:uint;
		protected var _fps:uint;
		protected var _ms:uint;
		protected var _ms_prev:uint;
		protected var _rt:uint;
		protected var _rn:uint;
		
		public var p:Panel;
		protected var fps_txt:Label;
		protected var bsSlider:HUISlider;
		protected var siSlider:HUISlider;
		protected var stiSlider:HUISlider;
		protected var edgeSlider:HUISlider;
        
		public function DemoFaceDetect()
		{
			if(stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		protected function init(e:Event = null):void
		{			
			initStage();
			initPanel();
			
			view = new Sprite;
			addChild(view);

			// web camera initiation
            initCamera(640, 480, 15);
            camBmp = new Bitmap(_cambuff); 
			view.addChild( camBmp );

			detectionMapOrig = _cambuff.clone();
			detectionMap = new BitmapData( w / scaleFactor, h / scaleFactor, false, 0 );
			drawMatrix = new Matrix( 1 / scaleFactor, 0, 0, 1 / scaleFactor );
			
			detectionMap.lock();
			detectionMapOrig.lock();
			
			faceRectContainer = new Sprite();
			
			view.y = 40;
			view.addChild( faceRectContainer );
			
			/*
			var b:Bitmap = new Bitmap(detectionMap);
			b.x = w - detectionMap.width;
			b.y = h - detectionMap.height;
			view.addChild(b);
			*/
			
			var iw:int = detectionMap.width;
			var ih:int = detectionMap.height;
			var sz:int = iw*ih;
			
			var detectorChunk:int = detector.calcRequiredChunkSize(iw, ih);
			var sobelChunk:int = sobel.calcRequiredChunkSize(iw, ih);
			var cannyChunk:int = 0;
			var maxEdgeChunk:int = IntMath.max(sobelChunk, cannyChunk);
            
            ram.endian = Endian.LITTLE_ENDIAN;
			ram.length = 1024 + detectorChunk * 4 + maxEdgeChunk + sz + (sz<<2);
			ram.position = 0;
			Memory.select(ram);
			
			var off:int = 1024;
			imgPtr = off;
			off += sz;
			edgesPtr = off;
			off += sz << 2;
			sobel.setup(off, iw, ih);
			//canny.setup(off, iw, ih);
			off += maxEdgeChunk;

			detectorPtr = off;

			imageRect = detectionMap.rect;
			
			detector.baseScale = baseScale;
			detector.increment = stepIncrement;
			detector.scaleIncrement = scaleIncrement;
			detector.edgesDensity = 255 * edgeDensity;
			detector.edgesPtr = edgesPtr;
			//detector.maxCandidatesToBreak = 6;

			detector.numSteps = 2;
			detector.onImageDataUpdate = updateImageAndEdges;
			
			detectorLE.edgesDensity = detectorRE.edgesDensity = detectorM.edgesDensity = detector.edgesDensity;
			
			imgU.setup(imgPtr, iw, ih);
			imgI.setup(edgesPtr, iw, ih);
			
			//var maxGrad:int = 32;
			//canny.lowThreshold = 0.42 * maxGrad;
			//canny.highThreshold = 0.44 * maxGrad;
			
			var myLoader:URLLoader = new URLLoader();
			myLoader.dataFormat = URLLoaderDataFormat.BINARY;
			myLoader.addEventListener(Event.COMPLETE, onUnZipComplete);
			myLoader.load(new URLRequest(ZIP_XML_URL));
		}
		
		protected function updateImageAndEdges():void
		{
			detectionMap.draw( _cambuff, drawMatrix, null, "normal", null, true );
			detectionMap.applyFilter( detectionMap, imageRect, ORIGIN, GRAYSCALE_MATRIX );
			
			var uptr:int = imgU.ptr;
			var iptr:int = imgI.ptr;
			var iw:int = detectionMap.width;
			var ih:int = detectionMap.height;
			var data:Vector.<uint> = detectionMap.getVector(imageRect);
			// pass data to memory
			imgU.fill(data);
			
			// stretch histogram to get better edges and contrast
			imgU.equalizeHist(iptr);
			
			// use edges to speed up detection
			sobel.detect(uptr, iptr, iw, ih);
			//canny.detect2(uptr, iptr, iw, ih);
		}
		
		private function onRender(e:Event):void
		{
			_cambuff.draw(_video, _cam_mtx);
			
			var faceRects:Vector.<Rectangle>;
			
			var t:int = getTimer();
			
			// simple one step way
			//faceRects = detector.detect(null, baseScale, scaleIncrement, stepIncrement, null);
			//faceRects = detector.groupRectangles(faceRects);
			//drawRects(faceRects, scaleFactor);
			
			// multi-step way
			detector.nextFrame();
			// if we at last step - check the result
			if(detector.state == detector.numSteps - 1)
			{
				faceRects = detector.result;
				faceRects = detector.groupRectangles(faceRects, 4);
				drawRects( faceRects, scaleFactor );
				
				// here u can try to localize eyes and mouth
				/*
				if (faceRects.length)
				{
					detectEyesAndMouth( faceRects[0] );
				}
				*/
			}
			
			_rt += getTimer()-t;
			_rn++;
			
			countFrameTime();
		}
		
		public function detectEyesAndMouth(r:Rectangle):void
		{
			var t:int;
			var eyeRects:Vector.<Rectangle>;
			
			var eyes_r:Rectangle = r.clone();
			var mouth_r:Rectangle = eyes_r.clone();
			eyes_r.height *= 0.375;
			eyes_r.width *= 0.5;
			eyes_r.y += eyes_r.height * 0.55;
			
			// LEFT EYE
			
			// debug search region
			//drawRects(Vector.<Rectangle>([eyes_r]), scaleFactor, false);
			
			t = getTimer();
			eyeRects = detectorLE.detect(eyes_r, 1, 1.1, 0.05, -1, detector);
			_rt += getTimer()-t;
			
			eyeRects = detectorLE.groupRectangles(eyeRects, 3);
			drawCircles(eyeRects, scaleFactor, false);
			
			// RIGHT EYE
			
			eyes_r.x += eyes_r.width;
			
			// debug search region
			//drawRects(Vector.<Rectangle>([eyes_r]), scaleFactor, false);
			
			t = getTimer();
			eyeRects = detectorRE.detect(eyes_r, 1, 1.1, 0.05, -1, detector);
			_rt += getTimer()-t;
			
			eyeRects = detectorRE.groupRectangles(eyeRects, 3);
			drawCircles(eyeRects, scaleFactor, false);
			
			// MOUTH
			
			mouth_r.y = mouth_r.bottom - mouth_r.height * 0.35;
			mouth_r.x += mouth_r.width * 0.2;
			mouth_r.width *= 0.6;
			//mouth_r.height *= 0.3;
			mouth_r.height = r.bottom - mouth_r.y;
			
			// debug search region
			//drawRects(Vector.<Rectangle>([mouth_r]), scaleFactor, false);
			
			t = getTimer();
			eyeRects = detectorM.detect( mouth_r, 1, 1.1, 0.05, -1, detector );
			_rt += getTimer()-t;
			
			eyeRects = detectorM.groupRectangles(eyeRects, 3);
			drawRects(eyeRects, scaleFactor, false);
		}
		
		public function drawCircles(faceRects:Vector.<Rectangle>, scale:Number = 1, clear:Boolean = true):void
		{
			var g:Graphics = faceRectContainer.graphics;
			if(clear) g.clear();
			g.lineStyle(2, 0x00ff00);
			for(var i:int = 0; i < faceRects.length; ++i)
			{
				var size:int = (faceRects[i].width * scale);
				g.drawCircle(faceRects[i].x * scale + (size>>1), faceRects[i].y * scale + (size>>1), size>>1);
			}
		}
		public function drawRects(faceRects:Vector.<Rectangle>, scale:Number = 1, clear:Boolean = true):void
		{			
			var g:Graphics = faceRectContainer.graphics;
			if(clear) g.clear();
			g.lineStyle(2, 0x00ff00);
			for(var i:int = 0; i < faceRects.length; ++i)
			{
				g.drawRect(faceRects[i].x * scale, faceRects[i].y * scale, faceRects[i].width * scale, faceRects[i].height * scale);
			}
		}
		
		protected function onUnZipComplete(e:Event):void
		{
			var zipFile:ZipFile = new ZipFile( URLLoader( e.currentTarget ).data as ByteArray );
			var offset:int = detectorPtr;
			var chunk:int = detector.calcRequiredChunkSize(detectionMap.width, detectionMap.height);
			
			var entry:ZipEntry = zipFile.getEntry(XML_FACE_URL);
			var data:ByteArray = zipFile.getInput(entry);
			var myXML:XML = XML(data.toString());

			detector.setup( offset, detectionMap, myXML, false );
			offset += chunk;
			
			entry = zipFile.getEntry(XML_MOUTH_URL);
			data = zipFile.getInput(entry);
			myXML = XML(data.toString());
			detectorM.setup( offset, detectionMap, myXML, false );
			offset += chunk;
			
			entry = zipFile.getEntry(XML_L_EYE_URL);
			data = zipFile.getInput(entry);
			myXML = XML(data.toString());
			detectorLE.setup( offset, detectionMap, myXML, false );
			offset += chunk;
			
			entry = zipFile.getEntry(XML_R_EYE_URL);
			data = zipFile.getInput(entry);
			myXML = XML(data.toString());
			detectorRE.setup( offset, detectionMap, myXML, false );
			offset += chunk;
			
			addEventListener(Event.ENTER_FRAME, onRender);
		}
		
		protected function countFrameTime(e:Event = null):void
		{
			_timer = getTimer();
			if( _timer - 1000 >= _ms_prev )
			{
				_ms_prev = _timer;

				fps_txt.text = 'FPS: ' + _fps + ' / ' + stage.frameRate +  "\nMATH: " + int(_rt/_rn+0.5) + 'ms';
				_fps = 0;
				_rt = _rn = 0;
			}

			_fps ++;
			_ms = _timer;
		}
		
		protected function initPanel():void
		{
			p = new Panel(this);
			p.width = 640;
			p.height = 40;

			Style.PANEL = 0x333333;
			Style.BUTTON_FACE = 0x333333;
			Style.LABEL_TEXT = 0xF6F6F6;

			fps_txt = new Label(p, 10, 5);
			fps_txt.name = 'fps_txt';
			
			fps_txt.text = 'LOADING FEATURES';
			
			new Label(p, 112, 5, 'BASE SCALE');
			bsSlider = new HUISlider(p, 105, 17, '', onSliderChange);
			bsSlider.setSliderParams(1, 4, baseScale);
			bsSlider.tick = 0.1;
			bsSlider.labelPrecision = 2;
			bsSlider.width = 150;
			
			new Label(p, 247, 5, 'SCALE INCREMENT');
			siSlider = new HUISlider(p, 240, 17, '', onSliderChange);
			siSlider.setSliderParams(1.1, 2, scaleIncrement);
			siSlider.labelPrecision = 2;
			siSlider.tick = 0.05;
			siSlider.width = 150;
			
			new Label(p, 382, 5, 'STEP INCREMENT');
			stiSlider = new HUISlider(p, 375, 17, '', onSliderChange);
			stiSlider.setSliderParams(0.02, 0.1, stepIncrement);
			stiSlider.labelPrecision = 3;
			stiSlider.tick = 0.01;
			stiSlider.width = 150;
			
			new Label(p, 512, 5, 'EDGES DENSITY');
			edgeSlider = new HUISlider(p, 505, 17, '', onSliderChange);
			edgeSlider.setSliderParams(0.001, 0.15, edgeDensity);
			edgeSlider.labelPrecision = 3;
			edgeSlider.tick = 0.0005;
			edgeSlider.width = 140;
		}

		protected function onSliderChange(e:Event):void
		{
			var sl:HUISlider = HUISlider(e.currentTarget);
			if(sl == bsSlider) 
			{
				baseScale = sl.value;
				detector.baseScale = baseScale;
			}
			else if(sl == siSlider) 
			{
				scaleIncrement = sl.value;
				detector.scaleIncrement = scaleIncrement;
			}
			else if(sl == stiSlider) 
			{
				stepIncrement = sl.value;
				detector.increment = stepIncrement;
			}
			else if(sl == edgeSlider)
			{
				edgeDensity = sl.value;
				detector.edgesDensity = 255 * edgeDensity;
				detectorLE.edgesDensity = detectorRE.edgesDensity = detectorM.edgesDensity = detector.edgesDensity;
			}
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
		
		protected function initStage():void
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			//stage.align = StageAlign.TOP_LEFT;

			var myContextMenu:ContextMenu = new ContextMenu();
			myContextMenu.hideBuiltInItems();

			var copyr:ContextMenuItem = new ContextMenuItem("© inspirit.ru", true, false);
			myContextMenu.customItems.push(copyr);

			contextMenu = myContextMenu;
		}
	}
}
