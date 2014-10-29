package com.esria.samples.dashboard.view
{
	import mx.containers.VBox;
	import mx.controls.Alert;
	import mx.events.FlexEvent;
	
	public class PodContentBase extends VBox
	{
		[Bindable]
		public var properties:XML;
		
		function PodContentBase()
		{
			super();
			percentWidth = 100;
			percentHeight = 100;
			addEventListener(FlexEvent.CREATION_COMPLETE, onCreationComplete);
		}
		
		private function onCreationComplete(e:FlexEvent):void
		{
		}
	}
}