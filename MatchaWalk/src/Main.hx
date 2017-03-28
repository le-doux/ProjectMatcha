
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

import luxe.importers.tiled.TiledMap;
import luxe.importers.tiled.TiledObjectGroup;
// import luxe.importers.tiled.TiledObject;

/*
NOTES & QUESTIONS
X fix rendering perf
- what resolution should we use?
- how do we handle window resizing? fixed multiples?
	- try other games: emulator, cat game
	- cat game
		- fixed aspect ratio: set number of sizes (1x, 2x, fullscreen)
- how can I control screen resizing in luxe?
- art
	- what tools?
	- how do I set up a workflow for mmg? git? an online mode? dropbox?
- gotta watch the cute thing
X animations
	X squish
	X teeter
- tilemap
- how do we handle transparency? is there a transparency color in luxe?
- how do we work together effectively?
- dialog
	- dialog system
	- dialog file format???
- tea making system
	+ inventory system
- going into and out of houses

*** what is the minimum we need to prototype the winter world ***
X tilemaps 
X stickers (whoooo)
X snow?
- doors
- walls
- sprites
- dialog
- items / invetory / tea system
- art (temporary)
- writing (temporary)
- a way to break up the work
	- install programs on mmg's pc
*/

class Main extends luxe.Game {

	var player : Sprite;
	var walkSpeed = 128;
	var isScreenTransition = false;

	// world-window prototype
	var worldWinW : Int = cast 384; // 384 px / 32 px = 12 tiles
	var worldWinH : Int = cast 288; // 288 px / 32 px = 9 tiles
	var worldCam : Camera;
	var worldBatcher : Batcher;
	var worldRenderTexture : RenderTexture;
	var worldWindowVisual : Visual;

	var gameWinW = 384 + 64 + 64;
	var gameWinH = 288 + 64 + 64;

	//clouds & snow
	var clouds : Array<Sprite> = [];
	var snowflakes : Array<Sprite> = [];

	//tilemap
	var map : TiledMap;
	var sprites : Array<Sprite> = [];
	var doors : Array<luxe.importers.tiled.TiledObject> = [];

	override function config(config:GameConfig) {

		config.window.title = 'matcha';
		config.window.width = gameWinW; // * 2;
		config.window.height = gameWinH; // * 2;
		config.window.fullscreen = false;
		config.window.resizable = true;
		// config.window.borderless = true;

		config.preload.textures.push({ id:'assets/daphne0.png' });
		config.preload.textures.push({ id:'assets/cloud0.png' });
		config.preload.textures.push({ id:'assets/snowflake0.png' });

		config.preload.textures.push( { id:'assets/house.png' });
		config.preload.textures.push( { id:'assets/snowtiles0.png' });
		config.preload.texts.push( { id:'assets/snowmap0.tmx' });
		config.preload.texts.push( { id:'assets/map2.tmx' });

		// config.preload.textures.push( { id:'assets/watercolor3.png' });

		return config;
	}

	override function ready() {

		// Luxe.core.app.config.window.
		// Luxe.fixed_frame_time = 1.0 / 20.0;

		// Luxe.fixed_timestep = true;
		// Luxe.fixed_frame_time = 1.0 / 10.0;

		// Luxe.renderer.clear_color = new Color(0,150/255,230/255);
		Luxe.renderer.clear_color = new Color(174/255,156/255,255/255);

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
		worldWindowVisual.texture.filter_min = worldWindowVisual.texture.filter_mag = FilterType.nearest;
		cast( worldWindowVisual.geometry, phoenix.geometry.QuadGeometry ).flipy = true;

		Luxe.camera.size = new Vector(gameWinW, gameWinH);
		Luxe.camera.size_mode = luxe.Camera.SizeMode.fit;
		Luxe.camera.center = new Vector(gameWinW/2,gameWinH/2);
		Luxe.on(luxe.Ev.windowresized, on_resize);

		player = new Sprite({
		  pos: new Vector(64,64),
		  size: new Vector(32,48),
		  // color: new Color(230/255,0/255,100/255),
		  texture: Luxe.resources.texture('assets/daphne0.png'),
		  depth: 1,
		  // centered: true,
		  batcher: worldBatcher,
		  origin: new Vector(16,48)
		});
		player.texture.filter_min = player.texture.filter_mag = FilterType.nearest;
		// player.scale = new Vector(0.9,1.1);
		// Actuate.tween( player.scale, 1, {x:1.1,y:0.9}).reflect().repeat().onUpdate( function() { player.scale = player.scale; } );
		playerTeeterAnim(4,1);

		// watercolor background
		// var bg = new Sprite({
		// 		size: new Vector(gameWinW, gameWinH),
		// 		texture: Luxe.resources.texture('assets/watercolor3.png'),
		// 		centered: false,
		// 		depth: 0
		// 	});

		// make clouds
		// for (i in 0 ... 15) {
		// 	var s = Luxe.utils.random.float(20,40);
		// 	var c = new Sprite({
		// 		   pos: new Vector(Luxe.utils.random.float(0,gameWinW),Luxe.utils.random.float(0,gameWinH)),
		// 		   size: new Vector( s * Luxe.utils.random.float(1.5,2), s ),
		// 		   texture: Luxe.resources.texture('assets/cloud0.png'),
		// 		   depth: 1
		// 	   });
		// 	c.texture.filter_min = c.texture.filter_mag = FilterType.nearest;
		// 	clouds.push(c);
		// }

		// make snow
		for (i in 0 ... 60) {
			var size = Luxe.utils.random.float(5,15);
			var snow = new Sprite({
				   pos: new Vector(Luxe.utils.random.float(0,gameWinW),Luxe.utils.random.float(0,gameWinH)),
				   size: new Vector(size,size),
				   texture: Luxe.resources.texture('assets/snowflake0.png'),
				   depth: 1,
				   centered: true
				});
			snow.texture.filter_min = snow.texture.filter_mag = FilterType.nearest;
			snowflakes.push( snow );
		}

		//debug box
		// Luxe.draw.rectangle({
		//         x:0,y:0,w:gameWinW,h:gameWinH,
		//         color:new Color(1,0,0),
		//     });

		// map
		loadLevel("snowmap0.tmx");
	} //ready

	function loadLevel(levelFile:String) {
		trace("load " + levelFile);

		// clear current level
		if (map != null) {
			trace("destroy map!!");
			map.destroy(true); //todo: are the tiles really being destroyed? (I think NOT --- could cause slowdowns)
		}
		for (s in sprites) {
			spriteStopAllAnimations(s); //instead, make the animations a component that removes itself on sprite deletion?
			s.destroy(true);
		}
		sprites = [];
		doors = [];

		// move player and camera
		trace("move player and camera!");
		trace(player.pos);
		player.pos = new Vector(64,64);
		// trace(Luxe.camera.pos);
		trace(worldCam.pos);
		worldCam.pos = new Vector(0,0);

		// load new level
		var map_data = Luxe.resources.text( 'assets/' + levelFile ).asset.text;
		map = new TiledMap({ format:'tmx', tiled_file_data: map_data });
		map.display({ filter:FilterType.nearest, batcher: worldBatcher, depth: 0 });
		// load images
		for (imageLayer in map.tiledmap_data.image_layers) {
			// trace(imageLayer.x + ", " + imageLayer.y);
			// trace(imageLayer.image.width + ", " + imageLayer.image.height);
			// trace('assets/' + imageLayer.image.source);
			var imageSprite = new Sprite({
					pos: new Vector(imageLayer.x+imageLayer.image.width/2, imageLayer.y+imageLayer.image.height),
					origin: new Vector(imageLayer.image.width/2, imageLayer.image.height),
					size: new Vector(imageLayer.image.width, imageLayer.image.height),
					texture: Luxe.resources.texture( 'assets/' + imageLayer.image.source ),
					batcher: worldBatcher,
					centered: false
				});
			imageSprite.texture.filter_min = imageSprite.texture.filter_mag = FilterType.nearest;
			imageSprite.depth = (imageSprite.pos.y / map.bounds.h) * 100;
			squishAnim( imageSprite, 1.02, 0.98, 1 );
			sprites.push( imageSprite );
		}
		for (objectGroup in map.tiledmap_data.object_groups) {
			if (objectGroup.name == "Doors") {
				doors = objectGroup.objects;
			}
		}
	}

	function drawDebugBackground() { // old background
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
	}

	function playerTeeterAnim( degrees:Float, time:Float ) {
		player.rotation_z = -degrees;
		Actuate.tween( player, time, {rotation_z:degrees})
				.reflect().repeat()
				.ease( luxe.tween.easing.Cubic.easeInOut )
				.onUpdate( function() { player.rotation_z = player.rotation_z; } );
	}

	function playerSquishAnim( scaleX:Float, scaleY:Float, time:Float ) {
		squishAnim( player, scaleX, scaleY, time );
	}

	function squishAnim( sprite:Sprite, scaleX:Float, scaleY:Float, time:Float ) {
		Actuate.tween( sprite.scale, time, {x:scaleX,y:scaleY})
			.reflect().repeat()
			.ease( luxe.tween.easing.Cubic.easeInOut )
			.onUpdate( function() { sprite.scale = sprite.scale; } );
	}

	function playerResetTransformAnim( time:Float ) {
		return Actuate.tween( player, time, { scale: new Vector(1,1), rotation_z:0 } )
				.ease( luxe.tween.easing.Cubic.easeInOut )
				.onUpdate( function() { player.scale = player.scale;  player.rotation_z = player.rotation_z; } );
	}

	function playerStopAllAnimations() {
		spriteStopAllAnimations(player);
	}

	function spriteStopAllAnimations(sprite:Sprite) {
		Actuate.stop(sprite);
		Actuate.stop(sprite.scale);
		sprite.rotation_z = 0;
		sprite.scale = new Vector(1,1);
	}

	function on_resize(e:snow.types.Types.WindowEvent) {
		trace("resize " + e.x + ", " + e.y);
		trace( Luxe.core.screen.bounds );
		Luxe.camera.center = new Vector(gameWinW/2,gameWinH/2);
	}

	override function onkeyup( e:KeyEvent ) {
	 // trace( worldCam.viewport );

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	var wasWalking = false;
	override function update(dt:Float) {
		// trace(worldCam.pos);
		if (!isScreenTransition){
			//walking
			var isWalking = false;
			if ( Luxe.input.keydown( luxe.Input.Key.up ) ) {
				player.pos.y -= walkSpeed * dt;
				isWalking = true;
			}
			else if ( Luxe.input.keydown( luxe.Input.Key.down ) ) {
				player.pos.y += walkSpeed * dt;
				isWalking = true;
			}
	
			if ( Luxe.input.keydown( luxe.Input.Key.left ) ) {
				player.pos.x -= walkSpeed * dt;
				isWalking = true;
			}
			else if ( Luxe.input.keydown( luxe.Input.Key.right ) ) {
				player.pos.x += walkSpeed * dt;
				isWalking = true;
			}

			if (isWalking && !wasWalking) {
				playerStopAllAnimations();
				// playerResetTransformAnim(0.2).onComplete( function() { playerSquishAnim(1.1,0.9,0.25); } );
				playerSquishAnim(1.1,0.9,0.25);
			}
			else if (!isWalking && wasWalking) {
				playerStopAllAnimations();
				// playerResetTransformAnim(0.2).onComplete( function() { playerTeeterAnim(4,1); playerSquishAnim(1.05,0.95,0.5); } );
				playerTeeterAnim(4,1);
				playerSquishAnim(0.95,1.05,0.5);
			}
			wasWalking = isWalking;

			//update player z
			player.depth = (player.pos.y / map.bounds.h) * 100;

			// camera
			var playerCenter = new Vector( player.pos.x, player.pos.y - (player.size.y/2) );
			if (playerCenter.y < worldCam.pos.y - 5) {
				cameraSlideTransition(0,-worldWinH);
			}
			else if (playerCenter.y > worldCam.pos.y + worldWinH + 5) {
				cameraSlideTransition(0,worldWinH);
			}
			else if (playerCenter.x < worldCam.pos.x - 5) {
				cameraSlideTransition(-worldWinW,0);
			}
			else if (playerCenter.x > worldCam.pos.x + worldWinW + 5) {
				cameraSlideTransition(worldWinW,0);
			}

			// doors
			for (door in doors) {
				if (playerCenter.x > door.pos.x && playerCenter.x < door.pos.x + door.width && 
					playerCenter.y > door.pos.y && playerCenter.y < door.pos.y + door.height)
				{
					loadLevel( door.properties["Destination"] );
					break;
				}
			}
		}


		//weather effects
		for (c in clouds) {
			c.pos.x -= 20 * dt;
			if (c.pos.x + c.size.x < 0) c.pos.x = gameWinW;
		}

		for (i in 0 ... snowflakes.length) {
			var s = snowflakes[i];
			var d : Float = (cast(i,Float)/snowflakes.length);
			s.pos.y += (20 + (30 * Math.sin( d * Math.PI ))) * dt;
			s.pos.x += (5 + (10 * Math.sin( (1-d) * Math.PI ))) * dt;
			s.rotation_z += (5 + (10 * Math.sin( d * Math.PI ))) * dt;
			if (s.pos.y > gameWinH) s.pos.y = 0;
			if (s.pos.x > gameWinW) s.pos.x = 0;
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
		return x < 0 || y < 0 || x > map.bounds.w - worldWinW || y > map.bounds.h - worldWinH;
	}

	function renderWorld() {

		//copy the source to the worldRenderTexture

		var prev_target = Luxe.renderer.target;

		Luxe.renderer.target = worldRenderTexture;

		worldBatcher.draw();

		Luxe.renderer.target = prev_target;

	}


} //Main
