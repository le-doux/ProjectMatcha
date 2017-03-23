
import luxe.Input;
import luxe.Color;
import luxe.GameConfig;
import luxe.Vector;
import luxe.Sprite;
import luxe.tween.Actuate;
import luxe.Camera;
import luxe.Visual;

import phoenix.Batcher;
import phoenix.RenderTexture;
import phoenix.Texture;
import phoenix.Texture.FilterType;

import snow.modules.opengl.GL;
import snow.api.buffers.Uint8Array;

using cpp.NativeArray;

/*
NOTES
- pure-2d vs pseudo-3d
- strict screen-based rooms, or larger ones?
- how/should the sky be visible?
- fully top-down view? (vs some kind of side scrolling?)
- what is a good screen resolution?
- how big is the character compaired to the screen?
- dialog _boxes_ or speech _bubbles_

border thing
- check out grab_frame() from https://github.com/underscorediscovery/luxe-gifcapture/blob/master/luxe/gifcapture/LuxeGifCapture.hx to see how we can render something and then put a border around it
- options:
	- texture with hole in it
	- pre-render scene and stick it on a quad
*/

class Main extends luxe.Game {

    var player : Sprite;
    var walkSpeed = 128;
    var isScreenTransition = false;

    // world-window prototype
    var worldWinW : Int = cast 384;
    var worldWinH : Int = cast 288;
    var worldCam : Camera;
    var worldBatcher : Batcher;
    var worldRenderTexture : RenderTexture;
    var worldWindowVisual : Visual;

    var gameWinW = 384 + 64 + 64;
    var gameWinH = 288 + 64 + 64;

    //clouds
    var clouds : Array<Sprite> = [];

	override function config(config:GameConfig) {

		config.window.title = 'matcha';
		config.window.width = gameWinW*2;
		config.window.height = gameWinH*2;
		config.window.fullscreen = false;
        // config.window.resizable = false;

        config.preload.textures.push({ id:'assets/daphne0.png' });
        config.preload.textures.push({ id:'assets/cloud0.png' });

		return config;
	}

    override function ready() {
        // Luxe.fixed_frame_time = 1.0 / 20.0;

        // Luxe.fixed_timestep = true;
        // Luxe.fixed_frame_time = 1.0 / 10.0;

    	Luxe.renderer.clear_color = new Color(0,150/255,230/255);
        Luxe.renderer.

        worldCam = new Camera({name:"worldCam"});
        worldBatcher = Luxe.renderer.create_batcher({ name:"worldBatcher", camera:worldCam.view, no_add:true });
        worldRenderTexture = new RenderTexture({ id:"worldRenderTexture", width:worldWinW, height:worldWinH });
        worldWindowVisual = new Visual({ 
            pos:new Vector(gameWinW/2,gameWinH/2), 
            size: new Vector(worldWinW,worldWinH),
            origin: new Vector(worldWinW/2,worldWinH/2), //centered
            depth: 2
        });
        worldWindowVisual.texture = worldRenderTexture;
        cast( worldWindowVisual.geometry, phoenix.geometry.QuadGeometry ).flipy = true;

        Luxe.camera.size = new Vector(gameWinW, gameWinH);
        Luxe.camera.size_mode = luxe.Camera.SizeMode.fit;
        Luxe.camera.center = new Vector(gameWinW/2,gameWinH/2);
        Luxe.on(luxe.Ev.windowresized, on_resize);

        //make solid background
        Luxe.draw.box({
                x: -worldWinW, y: -worldWinH,
                w: worldWinW * 3, h: worldWinH * 3,
                color: new Color(0,230/255,150/255),
                depth: 0,
                batcher: worldBatcher
            });

        //make random grid squares
        for (i in 0 ... 100) {
            var gridX = Luxe.utils.random.int(-12,24);
            var gridY = Luxe.utils.random.int(-9,18);
            Luxe.draw.box({
                    x: gridX * 32, y: gridY * 32, w: 32, h: 32, color: new Color(0,130/255,50/255), depth: 1,
                    batcher: worldBatcher
                });
        }

        player = new Sprite({
            pos: new Vector(100,100),
            size: new Vector(32,48),
            // color: new Color(230/255,0/255,100/255),
            texture: Luxe.resources.texture('assets/daphne0.png'),
            depth: 2,
            centered: true,
            batcher: worldBatcher
        });
        player.texture.filter_min = player.texture.filter_mag = FilterType.nearest;


        // make clouds
        for (i in 0 ... 15) {
            var s = Luxe.utils.random.float(20,40);
            var c = new Sprite({
                    pos: new Vector(Luxe.utils.random.float(0,gameWinW),Luxe.utils.random.float(0,gameWinH)),
                    size: new Vector( s * Luxe.utils.random.float(1.5,2), s ),
                    texture: Luxe.resources.texture('assets/cloud0.png'),
                    depth: 1
                });
            c.texture.filter_min = c.texture.filter_mag = FilterType.nearest;
            clouds.push(c);
        }

        //debug box
        // Luxe.draw.rectangle({
        //         x:0,y:0,w:gameWinW,h:gameWinH,
        //         color:new Color(1,0,0),
        //     });
    } //ready

    function on_resize(e:snow.types.Types.WindowEvent) {
        Luxe.camera.center = new Vector(gameWinW/2,gameWinH/2);
    }

    override function onkeyup( e:KeyEvent ) {
    	trace( worldCam.viewport );

        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }

    } //onkeyup

    override function update(dt:Float) {
        // trace(worldCam.pos);
        if (!isScreenTransition){
            if ( Luxe.input.keydown( luxe.Input.Key.up ) ) {
                player.pos.y -= walkSpeed * dt;
            }
            else if ( Luxe.input.keydown( luxe.Input.Key.down ) ) {
                player.pos.y += walkSpeed * dt;
            }
    
            if ( Luxe.input.keydown( luxe.Input.Key.left ) ) {
                player.pos.x -= walkSpeed * dt;
            }
            else if ( Luxe.input.keydown( luxe.Input.Key.right ) ) {
                player.pos.x += walkSpeed * dt;
            }

            if (player.pos.y < worldCam.pos.y - 5) {
                cameraSlideTransition(0,-worldWinH);
            }
            else if (player.pos.y > worldCam.pos.y + worldWinH + 5) {
                cameraSlideTransition(0,worldWinH);
            }
            else if (player.pos.x < worldCam.pos.x - 5) {
                cameraSlideTransition(-worldWinW,0);
            }
            else if (player.pos.x > worldCam.pos.x + worldWinW + 5) {
                cameraSlideTransition(worldWinW,0);
            }
        }

        for (c in clouds) {
            c.pos.x -= 20 * dt;
            if (c.pos.x + c.size.x < 0) c.pos.x = gameWinW;
        }

        // renderWorld();

    } //update

    override function onprerender() {
        renderWorld();
    }

    function cameraSlideTransition(xDelta:Float,yDelta:Float) {
        var xDest = worldCam.pos.x + xDelta;
        var yDest = worldCam.pos.y + yDelta;
        if ( wouldCameraBeOutOfBounds(xDest,yDest) ) return;

        isScreenTransition = true;
        Actuate.tween( worldCam.pos, 0.3, { x: xDest, y: yDest } )
            .onUpdate( function() { worldCam.pos = worldCam.pos; } ) // why is this necessary???
            .onComplete( function() { isScreenTransition = false; worldCam.pos = worldCam.pos; } );
    }

    // todo - need more flexible definition of scene bounds
    function wouldCameraBeOutOfBounds(x:Float,y:Float) {
        return x < -worldWinW || y < -worldWinH || x > worldWinW || y > worldWinH;
    }

    function renderWorld() {

        //copy the source to the worldRenderTexture

        var prev_target = Luxe.renderer.target;

        Luxe.renderer.target = worldRenderTexture;

        worldBatcher.draw();

        Luxe.renderer.target = prev_target;

    }


} //Main
