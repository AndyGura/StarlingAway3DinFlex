package com.andrewgura.stageComponentsWrapper {
import away3d.core.managers.Stage3DManager;
import away3d.core.managers.Stage3DProxy;
import away3d.events.Stage3DEvent;

import flash.display.BlendMode;
import flash.display.DisplayObject;
import flash.display.Sprite;
import flash.display.Stage;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.Event;
import flash.geom.Point;
import flash.geom.Rectangle;

import mx.core.FlexGlobals;
import mx.core.UIComponent;
import mx.events.FlexEvent;
import mx.events.ResizeEvent;

import spark.components.Group;
import spark.components.supportClasses.GroupBase;
import spark.core.MaskType;

import starling.core.Starling;

public class StageComponent extends Group {

    protected static var stage3DProxy:Stage3DProxy;

    protected var isNeedToRender:Boolean = false;

    protected static var isReady:Boolean = false;
    protected static var addedToStageHandlers:Array = [];
    protected static var instances:Array = [];

    public static var initialize:* = function init():void {
        var application:DisplayObject = DisplayObject(FlexGlobals.topLevelApplication);
        if (application.stage) {
            onApplicationAddedToStage();
        } else {
            application.addEventListener(Event.ADDED_TO_STAGE, onApplicationAddedToStage);
        }
    }();

    private static function onApplicationAddedToStage(event:Event = null):void {
        var stage:Stage = FlexGlobals.topLevelApplication.stage;
        stage.addEventListener(ResizeEvent.RESIZE, onStageResized);
        stage.align = StageAlign.TOP_LEFT;
        stage.scaleMode = StageScaleMode.NO_SCALE;

        var stage3DManager:Stage3DManager = Stage3DManager.getInstance(stage);
        stage3DProxy = stage3DManager.getFreeStage3DProxy();
        stage3DProxy.addEventListener(Stage3DEvent.CONTEXT3D_CREATED, onContextCreated);
        stage3DProxy.antiAlias = 8;
        stage3DProxy.color = 0x0;
    }

    private static function onContextCreated(event:Stage3DEvent):void {
        isReady = true;
        for each (var handler:Function in addedToStageHandlers) {
            handler(new Event(Event.ADDED_TO_STAGE));
        }
    }

    public function StageComponent() {
        super();
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }

    protected function onAddedToStage(event:Event):void {
        initialize();
        instances.push(this);
        if (!isReady) {
            addedToStageHandlers.push(onAddedToStage);
            return;
        }
        addEventListener(Event.ENTER_FRAME, _onEnterFrame);
    }

    protected function initStageComponent():void {
        updateMask();
        setupParents();
        if (isGloballyVisible()) {
            setMask();
            isShow = true;
            visibleStageComponentsCount++;
            if (visibleStageComponentsCount == 1) {
                onStageResized();
            }
        }
    }

    protected function _onEnterFrame(e:Event):void {
        var isNeedToRender:Boolean = false;
        var instance:StageComponent;
        for each (instance in instances) {
            isNeedToRender ||= instance.isNeedToRender;
            if (isNeedToRender) {
                continue;
            }
        }
        if (!isNeedToRender) {
            return;
        }
        stage3DProxy.clear();
        for each (instance in instances) {
            if (instance.isNeedToRender) {
                instance.render();
            }
        }
        stage3DProxy.present();
    }

    protected static function onStageResized(e:Event = null):void {
        if (visibleStageComponentsCount == 0) {
            return;
        }
        var stage:Stage = FlexGlobals.topLevelApplication.stage;
        if (stage.stageWidth == 0 || stage.stageHeight == 0) {
            return;
        }
        var stageWidth:Number = Number.max(stage.stageWidth, 32);
        var stageHeight:Number = Number.max(stage.stageHeight, 32);
        var viewPortRectangle:Rectangle = new Rectangle();
        viewPortRectangle.width = stageWidth;
        viewPortRectangle.height = stageHeight;
        if (Starling.current && Starling.current.stage) {
            Starling.current.viewPort = viewPortRectangle;
            Starling.current.stage.stageWidth = stageWidth;
            Starling.current.stage.stageHeight = stageHeight;
        }
        stage3DProxy.width = stageWidth;
        stage3DProxy.height = stageHeight;
    }

    protected var application:DisplayObject = DisplayObject(FlexGlobals.topLevelApplication);
    protected var parentsInfo:Array = [];
    protected var isShow:Boolean = false;
    protected var currentMask:Sprite;
    protected static var maskGroup:Group;
    protected static var fullMask:UIComponent;
    protected static var visibleStageComponentsCount:Number = 0;

    protected function setupParents():void {
        runOnParents(a);
        function a(displayObject:DisplayObject):void {
            parentsInfo.push({displayObject: displayObject, originalMask: displayObject.mask});
            displayObject.addEventListener(FlexEvent.SHOW, hideShowHandler);
            displayObject.addEventListener(FlexEvent.HIDE, hideShowHandler);
        }
    }

    override public function validateDisplayList():void {
        super.validateDisplayList();
        if (visibleStageComponentsCount == 0) {
            return;
        }
        updateMask();
    }

    protected function updateMask():void {
        if (!fullMask) {
            fullMask = new UIComponent();
            fullMask.blendMode = BlendMode.LAYER;
        }
        if (!maskGroup) {
            maskGroup = new Group();
            maskGroup.width = application.width;
            maskGroup.height = application.height;
            maskGroup.addElement(fullMask);
        }
        fullMask.graphics.clear();
        fullMask.graphics.beginFill(0x666666);
        fullMask.graphics.drawRect(0, 0, application.width, application.height);
        fullMask.graphics.endFill();

        var thisRealPosition:Point = localToGlobal(new Point());
        if (!currentMask) {
            currentMask = new Sprite();
            currentMask.blendMode = BlendMode.ERASE;
        }
        currentMask.graphics.clear();
        currentMask.graphics.beginFill(0);
        currentMask.graphics.drawRect(thisRealPosition.x, thisRealPosition.y, this.width, this.height);
        currentMask.graphics.endFill();
    }

    override public function invalidateDisplayList():void {
        super.invalidateDisplayList();
        isNeedToRender = true;
    }

    protected function setMask():void {
        for each (var o:* in parentsInfo) {
            var displayObject:DisplayObject = o.displayObject;
            if (displayObject == this || !(displayObject is GroupBase)) {
                continue;
            }
            GroupBase(displayObject).mask = maskGroup;
            GroupBase(displayObject).maskType = MaskType.ALPHA;
        }
    }

    protected function unsetMask():void {
        if (visibleStageComponentsCount == 0) {
            for each (var o:* in parentsInfo) {
                var displayObject:DisplayObject = o.displayObject;
                if (displayObject == this || !(displayObject is GroupBase)) {
                    continue;
                }
                GroupBase(displayObject).mask = null;
            }
        }
    }

    protected function hideShowHandler(event:FlexEvent):void {
        if (isGloballyVisible()) {
            if (!isShow) {
                updateMask();
                setMask();
                isShow = true;
                visibleStageComponentsCount++;
                fullMask.addChild(currentMask);
                if (visibleStageComponentsCount == 1) {
                    onStageResized();
                }
            }
        } else {
            if (isShow) {
                isShow = false;
                visibleStageComponentsCount--;
                fullMask.removeChild(currentMask);
                unsetMask();
            }
        }
    }

    protected function isGloballyVisible():Boolean {
        var isVisible:Boolean = true;
        if (parentsInfo.length == 0) {
            return false;
        }
        for each (var info:* in parentsInfo) {
            var displayObject:DisplayObject = info.displayObject;
            if (!displayObject.visible) {
                isVisible = false;
                break;
            }
        }
        return isVisible;
    }

    private function runOnParents(func:Function, displayObject:DisplayObject = null):void {
        if (!displayObject) {
            displayObject = this;
        }
        func(displayObject);
        if (displayObject != application) {
            runOnParents(func, displayObject.parent);
        }
    }

    protected function render():void {
        isNeedToRender = false;
    }
}
}
