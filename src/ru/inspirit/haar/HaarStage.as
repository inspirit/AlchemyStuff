package ru.inspirit.haar 
{

	/**
	 * @author Eugene Zatepyakin
	 */
	internal final class HaarStage
	{
		public var threshold:Number;
		public var nextStage:HaarStage;
		public var features:HaarFeature;
		public var trees:HaarTree;
	}
}
