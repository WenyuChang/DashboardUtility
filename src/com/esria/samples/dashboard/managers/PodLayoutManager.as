package com.esria.samples.dashboard.managers
{	
	import com.esria.samples.dashboard.events.LayoutChangeEvent;
	import com.esria.samples.dashboard.events.PodStateChangeEvent;
	import com.esria.samples.dashboard.view.DragHighlight;
	import com.esria.samples.dashboard.view.Pod;
	
	import flash.events.EventDispatcher;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import mx.containers.Canvas;
	import mx.core.Application;
	import mx.effects.Move;
	import mx.effects.Parallel;
	import mx.effects.Resize;
	import mx.effects.easing.Exponential;
	import mx.events.DragEvent;
	import mx.events.ResizeEvent;

	[Event(name="update", type="com.esria.samples.dashboard.events.LayoutChangeEvent")]

	public class PodLayoutManager extends EventDispatcher
	{
		public var id:String;
		public var layoutNum:int = 1;
		public var items:Array = new Array();
		public var minimizedItems:Array = new Array();
		public var maximizedPod:Pod;
		
		private var dragHighlightItems:Array = new Array();		// Stores the highlight items used to designate a drop area.
		private var gridPoints:Array = new Array();				// Stores the x,y of each pod in the grid.
		
		private var currentDragPod:Pod;
		private var currentVisibleHighlight:DragHighlight;
		private var currentDropIndex:Number;
		private var currentDragPodMove:Move;
		
		private var _container:Canvas;
		
		private var parallel:Parallel;							// The main effect container.
		private var maximizeParallel:Parallel;
		
		private var itemWidth:Number;
		private var itemHeight:Number;
		
		private static const POD_GAP:Number = 10;				// The vertical and horizontal gap between pods.
		private static const TASKBAR_HEIGHT:Number = 25;		// The height of the area for minimized pods.
		private static const TASKBAR_HORIZONTAL_GAP:Number = 5; // The horizontal gap between minimized pods.
		private static const TASKBAR_ITEM_WIDTH:Number = 150;	// The preferred minimized pod width if there is available space.
		private static const TASKBAR_PADDING_TOP:Number = 10;	// The gap between the taskbar and the bottom of the last row of pods.
		private static const PADDING_RIGHT:Number = 5;			// The right padding within the container when laying out pods.
		
		public function removeNullItems():void
		{
			var a:Array = new Array();
			var len:Number = items.length;
			for (var i:Number = 0; i < len; i++)
			{
				if (items[i] != null)
					a.push(items[i]);
			}
			
			items = a;
			
			_container.addEventListener(ResizeEvent.RESIZE, updateLayout);
		}
		
		public function set container(canvas:Canvas):void
		{
			_container = canvas;
		}
		
		public function get container():Canvas
		{
			return _container;
		}
		
		public function addMinimizedItemAt(pod:Pod, index:Number):void
		{	
			if (index == -1)
				index = minimizedItems.length;
			
			pod.minimize();
			
			minimizedItems[index] = pod;
			initItem(pod);
		}
		
		public function addItemAt(pod:Pod, index:Number, maximized:Boolean):void
		{	
			if (maximized)
			{
				maximizedPod = pod;
				pod.maximize();
			}
			
			items[index] = pod;
			initItem(pod);
		}
		
		private function initItem(pod:Pod):void
		{
			container.addChild(pod);
			
			pod.addEventListener(DragEvent.DRAG_START, onDragStartPod);
			pod.addEventListener(DragEvent.DRAG_COMPLETE, onDragCompletePod);
			pod.addEventListener(PodStateChangeEvent.MAXIMIZE, onMaximizePod);
			pod.addEventListener(PodStateChangeEvent.MINIMIZE, onMinimizePod);
			pod.addEventListener(PodStateChangeEvent.RESTORE, onRestorePod);
			
			var dragHighlight:DragHighlight = new DragHighlight();
			dragHighlight.visible = false;
			dragHighlightItems.push(dragHighlight);
			container.addChild(dragHighlight);
		}
		
		private function onMaximizePod(e:PodStateChangeEvent):void
		{
			var pod:Pod = Pod(e.currentTarget);
			maximizeParallel = new Parallel();
			maximizeParallel.duration = 1000;
			addResizeAndMoveToParallel(pod, maximizeParallel, availablePodWidth, availableMaximizedPodHeight, 0, 0);
			maximizeParallel.play();
			
			maximizedPod = pod;
			dispatchEvent(new LayoutChangeEvent(LayoutChangeEvent.UPDATE));
		}
		
		private function onMinimizePod(e:PodStateChangeEvent):void
		{
			if (maximizeParallel != null && maximizeParallel.isPlaying)
				maximizeParallel.pause();
			
			var pod:Pod = Pod(e.currentTarget);
			items.splice(pod.index, 1);
			
			if (pod.windowState == Pod.WINDOW_STATE_MAXIMIZED)
				maximizedPod = null;
					
			minimizedItems.push(pod);
			
			updateLayout(true);
			
			dispatchEvent(new LayoutChangeEvent(LayoutChangeEvent.UPDATE));
		}
		
		private function onRestorePod(e:PodStateChangeEvent):void
		{
			var pod:Pod = Pod(e.currentTarget);
			if (pod.windowState == Pod.WINDOW_STATE_MAXIMIZED)
			{
				if (maximizeParallel != null && maximizeParallel.isPlaying)
					maximizeParallel.pause();
				
				maximizedPod = null;
				maximizeParallel = new Parallel();
				var point:Point = Point(gridPoints[pod.index]);
				addResizeAndMoveToParallel(pod, maximizeParallel, itemWidth, itemHeight, point.x, point.y);
				maximizeParallel.play();
			}
			else if (pod.windowState == Pod.WINDOW_STATE_MINIMIZED)
			{
				var len:Number = minimizedItems.length;
				for (var i:Number = 0; i < len; i++)
				{
					if (minimizedItems[i] == pod)
					{
						minimizedItems.splice(i, 1);
						break;
					}
				}
				
				if (pod.index < (items.length - 1))
					items.splice(pod.index, 0, pod);
				else
					items.push(pod);
					
				updateLayout(true);
			}
			
			dispatchEvent(new LayoutChangeEvent(LayoutChangeEvent.UPDATE));
		}
		
		private function onDragStartPod(e:DragEvent):void
		{
			currentDragPod = Pod(e.currentTarget);
			var len:Number = items.length;
			for (var i:Number = 0; i < len; i++)
			{
				if (Pod(items[i]) == currentDragPod)
				{
					currentDropIndex = i;
					break;
				}
			}
			Application.application.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		}
		
		private function onDragCompletePod(e:DragEvent):void
		{
			Application.application.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
			
			if (currentVisibleHighlight != null)
				currentVisibleHighlight.visible = false;
			
			var point:Point = Point(gridPoints[currentDropIndex]);
			if (point.x != currentDragPod.x || point.y != currentDragPod.y)
			{
				if (parallel != null && parallel.isPlaying)
					parallel.pause();
				else if (parallel == null)
				{
					parallel = new Parallel();
					parallel.duration = 1000;
				}
				
				addResizeAndMoveToParallel(currentDragPod, parallel, dragHighlightItems[currentDropIndex].width, dragHighlightItems[currentDropIndex].height, point.x, point.y);
				parallel.play();
				
				dispatchEvent(new LayoutChangeEvent(LayoutChangeEvent.UPDATE));
			}
		}
		
		private function onMouseMove(e:MouseEvent):void
		{
			var len:Number = items.length;
			var dragHighlightItem:DragHighlight;
			var overlapArea:Number = 0; 	// Keeps track of the amount (w *h) of overlap between rectangles.
			var dragPodRect:Rectangle = new Rectangle(currentDragPod.x, currentDragPod.y, currentDragPod.width, currentDragPod.height);
			var dropIndex:Number = -1;		// The new drop index. This will create a range from currentDropIndex to dropIndex for transtions below.
			
			for (var i:Number = 0; i < len; i++)
			{
				dragHighlightItem = DragHighlight(dragHighlightItems[i]);
				dragHighlightItem.visible = false;
				if (currentDragPod.hitTestObject(dragHighlightItem))
				{
					var dragHighlightItemRect:Rectangle = new Rectangle(dragHighlightItem.x, dragHighlightItem.y, dragHighlightItem.width, dragHighlightItem.height);
					var intersection:Rectangle = dragHighlightItemRect.intersection(dragPodRect);
					if ((intersection.width * intersection.height) > overlapArea)
					{
						currentVisibleHighlight = dragHighlightItem;
						overlapArea = intersection.width * intersection.height;
						dropIndex = i;
					}
				}
			}
			
			if (currentDropIndex != dropIndex) // Make sure we have a new drop index so we don't create redudant effects.
			{
				if (dropIndex == -1) // User is not over a highlight.
					dropIndex = currentDropIndex;
				
				if (currentDragPodMove != null && currentDragPodMove.isPlaying)
					currentDragPodMove.pause();
				
				if (parallel != null && parallel.isPlaying)
					parallel.pause();
				
				parallel = new Parallel();
				parallel.duration = 1000;
				
				var a:Array = new Array();
				a[dropIndex] = currentDragPod;
				currentDragPod.index = dropIndex;
				
				for (i = 0; i < len; i++)
				{
					var targetX:Number;
					var targetY:Number;
					var point:Point;
					var pod:Pod = Pod(items[i]);
					
					var index:Number;
					if (i != currentDropIndex)
					{
						if ((i < currentDropIndex && i < dropIndex) ||
							(i > currentDropIndex && i > dropIndex))
							index = i;
						else if (i > currentDropIndex && i <= dropIndex)
							index = i - 1;
						else if (i < currentDropIndex && i >= dropIndex)
							index = i + 1;
						else
							index = i;
						
						a[index] = pod;
						pod.index = index;
						
						point = Point(gridPoints[index]);
						
						targetX = point.x;
						targetY = point.y;
						
						if (targetX != pod.x || targetY != pod.y)
						{
							addResizeAndMoveToParallel(pod, parallel, dragHighlightItems[currentDropIndex].width, dragHighlightItems[currentDropIndex].height, targetX, targetY);
						}
					}
				}
				
				if (parallel.children.length > 0)
					parallel.play();
			
				currentDropIndex = dropIndex;
				
				items = a;
			}
			
			currentVisibleHighlight.visible = true;
		}
		
		public function equalityLayout(tween:Boolean=true):void
		{
			var len:Number = items.length;
			var sqrt:Number = Math.floor(Math.sqrt(len));
			var numCols:Number = Math.ceil(len / sqrt)>3?3:Math.ceil(len / sqrt);
			var numRows:Number = Math.ceil(len / numCols);
			var col:Number = 0;
			var row:Number = 0;
			var pod:Pod;
			itemWidth = Math.round(availablePodWidth / numCols - ((POD_GAP * (numCols - 1)) / numCols));
			itemHeight = Math.round(availablePodHeight / numRows - ((POD_GAP * (numRows - 1)) / numRows));
			
			if(itemHeight>itemWidth)
				itemHeight = itemWidth;
			
			if (parallel != null && parallel.isPlaying)
				parallel.pause();
			
			if (tween)
			{
				parallel = new Parallel();
				parallel.duration = 1000;
			}
			
			for (var i:Number = 0; i < len; i++)
			{			
				if(i % numCols == 0 && i > 0)
				{
					row++;
					col = 0;
				}
				else if(i > 0)
				{
					col++;
				}
				
				var targetX:Number = col * itemWidth;
				var targetY:Number = row * itemHeight;
				
				if(col > 0) 
					targetX += POD_GAP * col;
				if(row > 0) 
					targetY += POD_GAP * row;
					
				targetX = Math.round(targetX);
				targetY = Math.round(targetY);
				
				pod = items[i];
				if (pod.windowState == Pod.WINDOW_STATE_MAXIMIZED)// Window is maximized so do not include in the grid
				{
					if (tween)
					{
						addResizeAndMoveToParallel(pod, parallel, availablePodWidth, availableMaximizedPodHeight, 0, 0);
					}
					else
					{
						pod.width = availablePodWidth;
						pod.height = availableMaximizedPodHeight;
					}
					
					container.setChildIndex(pod, container.numChildren - 1);
				}
				else
				{
					if (tween)
					{
						addResizeAndMoveToParallel(pod, parallel, itemWidth, itemHeight, targetX, targetY);
					}
					else
					{
						pod.width = itemWidth;
						pod.height = itemHeight;
						pod.x = targetX;
						pod.y = targetY;
					}
				}
					
				pod.index = i;
				
				gridPoints[i] = new Point(targetX, targetY);
			}
			
			len = minimizedItems.length;
			if (len > 0)
			{
				var totalMinimizedItemWidth:Number = len * TASKBAR_ITEM_WIDTH + (len -1) * TASKBAR_HORIZONTAL_GAP;
				var minimizedItemWidth:Number;
				if (totalMinimizedItemWidth > availablePodWidth)
					minimizedItemWidth = Math.round((availablePodWidth - (len - 1) * TASKBAR_HORIZONTAL_GAP) / len);
				else
					minimizedItemWidth = TASKBAR_ITEM_WIDTH;
				
				for (i = 0; i < len; i++)
				{
					pod = Pod(minimizedItems[i]);
					pod.height = Pod.MINIMIZED_HEIGHT;
					targetX = i * (TASKBAR_HORIZONTAL_GAP + minimizedItemWidth);
					if (tween)
					{
						addResizeAndMoveToParallel(pod, parallel, minimizedItemWidth, Pod.MINIMIZED_HEIGHT, targetX, minimizedPodY);
					}
					else
					{
						pod.width = minimizedItemWidth;
						pod.x = targetX;
						pod.y = minimizedPodY;
					}
				}
			}
			
			if (parallel != null && parallel.children.length > 0)
				parallel.play();
			
			len = dragHighlightItems.length;
			for (i = 0; i < len; i++)
			{
				var dragHighlight:DragHighlight = DragHighlight(dragHighlightItems[i]);
				if (i > (items.length - 1))
				{
					dragHighlight.visible = false;
					dragHighlight.x = 0;
					dragHighlight.y = 0;
					dragHighlight.width = 0;
					dragHighlight.height = 0;
				}
				else
				{
					var point:Point = Point(gridPoints[i]);
					dragHighlight.x = point.x;
					dragHighlight.y = point.y;
					dragHighlight.width = itemWidth;
					dragHighlight.height = itemHeight;
					container.setChildIndex(dragHighlight, i);
				}
			}
		}
		
		public function trisectionLayout(tween:Boolean=true):void
		{
			var len:Number = 3;
			var pod:Pod;
			var col:int = -1;
			
			if (parallel != null && parallel.isPlaying)
				parallel.pause();
			
			if (tween)
			{
				parallel = new Parallel();
				parallel.duration = 1000;
			}
			
			for (var i:Number = 0; i < len; i++)
			{
				var targetX:Number = 0;
				var targetY:Number = 0;
				if(i==0)
				{
					targetX = 0;
					targetY = 0;
					
					pod = items[i];
					
					if (pod.windowState == Pod.WINDOW_STATE_MAXIMIZED)
					{
						if (tween)
						{
							addResizeAndMoveToParallel(pod, parallel, availablePodWidth, availableMaximizedPodHeight, 0, 0);
						}
						else
						{
							pod.width = availablePodWidth;
							pod.height = availableMaximizedPodHeight;
						}
						
						container.setChildIndex(pod, container.numChildren - 1);
					}
					else
					{
						if (tween)
						{
							addResizeAndMoveToParallel(pod, parallel, availablePodWidth, Math.round(availablePodHeight / 2 - (POD_GAP / 2)), targetX, targetY);
						}
						else
						{
							pod.width = availablePodWidth;
							pod.height = Math.round(availablePodHeight / 2 - (POD_GAP / 2));
							pod.x = targetX;
							pod.y = targetY;
						}
					}
					
					pod.index = i;
				
					gridPoints[i] = new Point(targetX, targetY);
					
					var dragHighlight:DragHighlight = DragHighlight(dragHighlightItems[i]);
					if (i > (items.length - 1))
					{
						dragHighlight.visible = false;
						dragHighlight.x = 0;
						dragHighlight.y = 0;
						dragHighlight.width = 0;
						dragHighlight.height = 0;
					}
					else
					{
						var point:Point = Point(gridPoints[i]);
						dragHighlight.x = point.x;
						dragHighlight.y = point.y;
						dragHighlight.width = pod.width;
						dragHighlight.height = pod.height;
						container.setChildIndex(dragHighlight, i);
					}
				}
				else
				{
					col++;
					
					var targetX:Number = col * Math.round(availablePodWidth / 2 - (POD_GAP / 2)) + POD_GAP * col;
					var targetY:Number = Math.round(availablePodHeight / 2 - (POD_GAP / 2)) + POD_GAP;
					
					pod = items[i];
					
					if (pod.windowState == Pod.WINDOW_STATE_MAXIMIZED)
					{
						if (tween)
						{
							addResizeAndMoveToParallel(pod, parallel, availablePodWidth, availableMaximizedPodHeight, 0, 0);
						}
						else
						{
							pod.width = availablePodWidth;
							pod.height = availableMaximizedPodHeight;
						}
						
						container.setChildIndex(pod, container.numChildren - 1);
					}
					else
					{
						if (tween)
						{
							addResizeAndMoveToParallel(pod, parallel, availablePodWidth, Math.round(availablePodHeight / 2 - (POD_GAP / 2)), targetX, targetY);
						}
						else
						{
							pod.width = Math.round(availablePodWidth / 2 - (POD_GAP / 2));
							pod.height = Math.round(availablePodHeight / 2 - (POD_GAP / 2));
							pod.x = targetX;
							pod.y = targetY;
						}
					}
					
					pod.index = i;
				
					gridPoints[i] = new Point(targetX, targetY);
					
					var dragHighlight:DragHighlight = DragHighlight(dragHighlightItems[i]);
					if (i > (items.length - 1))
					{
						dragHighlight.visible = false;
						dragHighlight.x = 0;
						dragHighlight.y = 0;
						dragHighlight.width = 0;
						dragHighlight.height = 0;
					}
					else
					{
						var point:Point = Point(gridPoints[i]);
						dragHighlight.x = point.x;
						dragHighlight.y = point.y;
						dragHighlight.width = pod.width;
						dragHighlight.height = pod.height;
						container.setChildIndex(dragHighlight, i);
					}
				}
			}
			
			len = minimizedItems.length;
			if (len > 0)
			{
				var totalMinimizedItemWidth:Number = len * TASKBAR_ITEM_WIDTH + (len -1) * TASKBAR_HORIZONTAL_GAP;
				var minimizedItemWidth:Number;
				if (totalMinimizedItemWidth > availablePodWidth)
					minimizedItemWidth = Math.round((availablePodWidth - (len - 1) * TASKBAR_HORIZONTAL_GAP) / len);
				else
					minimizedItemWidth = TASKBAR_ITEM_WIDTH;
				
				for (i = 0; i < len; i++)
				{
					pod = Pod(minimizedItems[i]);
					pod.height = Pod.MINIMIZED_HEIGHT;
					targetX = i * (TASKBAR_HORIZONTAL_GAP + minimizedItemWidth);
					if (tween)
					{
						addResizeAndMoveToParallel(pod, parallel, minimizedItemWidth, Pod.MINIMIZED_HEIGHT, targetX, minimizedPodY);
					}
					else
					{
						pod.width = minimizedItemWidth;
						pod.x = targetX;
						pod.y = minimizedPodY;
					}
				}
			}
			
			if (parallel != null && parallel.children.length > 0)
				parallel.play();
		}
		
		public function updateLayout(tween:Boolean=true):void
		{
			switch(layoutNum)
			{
				case 1:
					equalityLayout(tween);
					break;
				case 2:
					trisectionLayout(tween);
					break;
			}
		}
		
		private function addResizeAndMoveToParallel(target:Pod, parallel:Parallel, widthTo:Number, heightTo:Number, xTo:Number, yTo:Number):void
		{
			var resize:Resize = new Resize(target);
			resize.widthTo = widthTo;
			resize.heightTo = heightTo;
			resize.easingFunction = Exponential.easeOut;
			parallel.addChild(resize);
			
			var move:Move = new Move(target);
			move.xTo = xTo;
			move.yTo = yTo;
			move.easingFunction = Exponential.easeOut;
			parallel.addChild(move);
		}
		
		private function get availablePodWidth():Number
		{
			return container.width - PADDING_RIGHT;
		}
		
		private function get availablePodHeight():Number
		{
			return container.height - TASKBAR_HEIGHT - TASKBAR_PADDING_TOP;
		}
		
		private function get availableMaximizedPodHeight():Number
		{
			return container.height;
		}
		
		private function get minimizedPodY():Number
		{
			return container.height - TASKBAR_HEIGHT;
		}
	}
}