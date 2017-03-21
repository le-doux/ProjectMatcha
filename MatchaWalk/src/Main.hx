
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
    var walkSpeed = 96;
    var isScreenTransition = false;

    // world-window prototype
    var worldWinW = 384;
    var worldWinH = 288;
    var worldCam : Camera;
    var worldBatcher : Batcher;
    var worldRenderTexture : RenderTexture;
    var worldWindowVisual : Visual;

	override function config(config:GameConfig) {

		config.window.title = 'matcha';
		config.window.width = worldWinW*2;
		config.window.height = worldWinH*2;
		config.window.fullscreen = false;
        // config.window.resizable = false;

		return config;
	}

    override function ready() {
    	// Luxe.renderer.clear_color = new Color(0,230/255,150/255);

        worldCam = new Camera({name:"worldCam"});
        worldBatcher = Luxe.renderer.create_batcher({ name:"worldBatcher", camera:worldCam.view, no_add:true });
        worldRenderTexture = new RenderTexture({ id:"worldRenderTexture", width:worldWinW, height:worldWinH });
        // worldBatcher.enabled = false;

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
            depth: 2,
            centered: true,
            batcher: worldBatcher
        });

        worldWindowVisual = new Visual({ size: new Vector(worldWinW,worldWinH) });

        // worldCam.center = new Vector(384/2, 288/2);

    	// worldCam.size_mode = worldCam.SizeMode.fit;
    	// worldCam.size = new Vector(200,200);

    	// Luxe.draw.rectangle({
    	// 		x:5,y:5,w:100,h:100,color: new Color(1,0,0)
    	// 	});
    	// Luxe.draw.rectangle({
    	// 		x:5,y:110,w:300,h:100,color: new Color(0,1,0)
    	// 	});

    } //ready

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
                cameraSlideTransition(0,-288);
            }
            else if (player.pos.y > worldCam.pos.y + 288 + 5) {
                cameraSlideTransition(0,288);
            }
            else if (player.pos.x < worldCam.pos.x - 5) {
                cameraSlideTransition(-384,0);
            }
            else if (player.pos.x > worldCam.pos.x + 384 + 5) {
                cameraSlideTransition(384,0);
            }
        }

        renderWorld();

        Luxe.renderer.clear_color = new Color(0,0,0);
    } //update

    function cameraSlideTransition(xDelta:Float,yDelta:Float) {
        isScreenTransition = true;
        Actuate.tween( worldCam.pos, 0.3, { x: worldCam.pos.x + xDelta, y: worldCam.pos.y + yDelta } )
            .onUpdate( function() { worldCam.pos = worldCam.pos; } ) // why is this necessary???
            .onComplete( function() { isScreenTransition = false; worldCam.pos = worldCam.pos; } );
    }

    function renderWorld() {
            Luxe.renderer.clear_color = new Color(0,230/255,150/255);

            //copy the source to the worldRenderTexture using a rendered quad

            var prev_target = Luxe.renderer.target;

            Luxe.renderer.target = worldRenderTexture;

            // Luxe.renderer.clear_color = new Color(0,230/255,150/255);
            worldBatcher.draw();

            Luxe.renderer.target = prev_target;

            //grab pixel data

            GL.bindFramebuffer(GL.FRAMEBUFFER, worldRenderTexture.framebuffer);
            GL.bindRenderbuffer(GL.RENDERBUFFER, worldRenderTexture.renderbuffer);

                //place to put the pixels
            var frame_data = new snow.api.buffers.Uint8Array(worldRenderTexture.width * worldRenderTexture.height * 4);

                //get the pixels of the worldRenderTexture buffer back out
            GL.readPixels(0, 0, worldRenderTexture.width, worldRenderTexture.height, GL.RGBA, GL.UNSIGNED_BYTE, frame_data);

                //reset the frame buffer state to previous
            GL.bindFramebuffer(GL.FRAMEBUFFER, Luxe.renderer.state.current_framebuffer);
            GL.bindRenderbuffer(GL.RENDERBUFFER, Luxe.renderer.state.current_renderbuffer);

            // trace(frame_data.length);

            // var frame_bytes = frame_data.toBytes();

            // frame_data = null;

            // trace(frame_bytes.length);

            // var frame_in = haxe.io.UInt8Array.fromBytes(frame_bytes);

            // trace(frame_in.length);
            // trace("---");
            

            // var frame_with_alpha = new snow.api.buffers.Uint8Array(worldRenderTexture.width * worldRenderTexture.height * 3);
            // var pixelCount : Int = cast (frame_data.length / 3);
            // trace(frame_data);
            // trace(pixelCount);
            // for (i in 0 ... pixelCount) {
            //     // trace(i);
            //     frame_with_alpha[ (i*4) + 0 ] = frame_data[ (i*3) + 0 ];
            //     frame_with_alpha[ (i*4) + 1 ] = frame_data[ (i*3) + 1 ];
            //     frame_with_alpha[ (i*4) + 2 ] = frame_data[ (i*3) + 2 ];
            //     frame_with_alpha[ (i*4) + 3 ] = cast 255; //alpha
            // }

            // frame_data = null;

            // //update texture on visual
            // trace("make texture");
            // if (worldWindowVisual.texture != null) worldWindowVisual.texture.invalidate();
            // worldWindowVisual.texture = new Texture({ id:"worldTex", width:worldWinW, height:worldWinH, pixels:frame_with_alpha, filter_min: FilterType.nearest, filter_mag: FilterType.nearest });
    
            // frame_with_alpha = null;    

            var frame_data_reversed = new snow.api.buffers.Uint8Array(worldRenderTexture.width * worldRenderTexture.height * 4);
            // frame_data_reversed.buffer.blit(0, frame_data.buffer, frame_data.buffer.byteLength-1, -(frame_data.buffer.byteLength-1));   
            // var len = frame_data.buffer.byteLength - 1;
            // var i = len;
            // while (i >= 0) {
            //     frame_data_reversed[ len - i ] = frame_data[ i ];
            //     i--;
            // }

            var i = 0;
            var pixelCount : Int = cast frame_data.buffer.byteLength / 4;
            while (i < pixelCount) {
                var j = pixelCount - i;
                frame_data_reversed[ (i*4) + 0 ] = frame_data[ (j*4) + 0 ];
                frame_data_reversed[ (i*4) + 1 ] = frame_data[ (j*4) + 1 ];
                frame_data_reversed[ (i*4) + 2 ] = frame_data[ (j*4) + 2 ];
                frame_data_reversed[ (i*4) + 3 ] = frame_data[ (j*4) + 3 ];
                i++;
            }

            if (worldWindowVisual.texture != null) worldWindowVisual.texture.invalidate();
            worldWindowVisual.texture = new Texture({ id:"worldTex", width:worldWinW, height:worldWinH, pixels:frame_data_reversed, filter_min: FilterType.nearest, filter_mag: FilterType.nearest });
    
    }


} //Main
