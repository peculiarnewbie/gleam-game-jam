/// 3D Game Example - Perspective Camera with Lighting
import gleam/float
import gleam/int
import gleam/io
import gleam/javascript/promise
import gleam/list
import gleam/option
import gleam_community/maths
import lustre
import lustre/attribute.{attribute, class}
import lustre/effect as effect_ui
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import pong/levels
import tiramisu
import tiramisu/asset
import tiramisu/background
import tiramisu/camera
import tiramisu/effect.{type Effect}
import tiramisu/geometry
import tiramisu/input
import tiramisu/light
import tiramisu/material
import tiramisu/scene
import tiramisu/spatial
import tiramisu/transform
import tiramisu/ui
import vec/vec3

pub type Direction {
  Forward
  Backward
}

pub type PlayerID {
  P1
  P2
}

pub type Player {
  Player(id: PlayerID, position: Float, speed: Float)
}

pub type Ball {
  Ball(
    position: vec3.Vec3(Float),
    velocity: Float,
    rotation: Float,
    direction: vec3.Vec3(Float),
    owner: PlayerID,
  )
}

pub type Game {
  Game(p1_score: Int, p2_score: Int)
}

pub type Model {
  Model(
    time: Float,
    p1: Player,
    p2: Player,
    ball: Ball,
    game: Game,
    load_state: LoadState,
    camera_type: levels.CameraType,
    level: levels.Level,
  )
}

pub type Msg {
  Tick
  ModelLoaded(asset.FBXData)
  LoadingFailed(asset.LoadError)
}

pub type Action {
  P1Move
  P2Move
}

pub type LoadState {
  Loading
  Loaded(asset.FBXData)
  Failed(String)
}

pub type UIModel {
  UIModel(state: Game)
}

pub type UIMsg {
  UpdateScore(Int, Int)
}

pub fn main() -> Nil {
  let assert Ok(_) =
    lustre.application(init_ui, update_ui, view_ui)
    |> lustre.start("#app", Nil)

  tiramisu.run(
    dimensions: option.None,
    background: background.Color(0x1a1a2e),
    init:,
    update:,
    view:,
  )
}

fn init_ui(_flags) {
  // Register with Tiramisu to receive game state updates
  #(UIModel(Game(0, 0)), ui.register_lustre())
}

fn update_ui(_: UIModel, msg: UIMsg) {
  case msg {
    UpdateScore(p1_score, p2_score) -> #(
      UIModel(state: Game(p1_score, p2_score)),
      effect_ui.none(),
    )
  }
}

fn view_ui(model: UIModel) -> Element(UIMsg) {
  // UI overlay - positioned fixed to cover entire viewport and overlay Tiramisu canvas
  html.div([class("fixed top-0 left-0 w-full h-full pointer-events-none")], [
    html.div(
      [
        class(
          "absolute top-5 left-5 p-4 bg-black/60 rounded-[5px] text-white font-sans pointer-events-auto",
        ),
      ],
      [
        html.div([class("mb-2.5")], [
          element.text("P1 Score: " <> int.to_string(model.state.p1_score)),
        ]),
        html.div([class("mb-2.5")], [
          element.text("P2 Score: " <> int.to_string(model.state.p2_score)),
        ]),
      ],
    ),
  ])
}

fn init(
  _ctx: tiramisu.Context(String),
) -> #(Model, Effect(Msg), option.Option(_)) {
  // Insert enemies
  //
  let load_effect =
    effect.from_promise(
      promise.map(asset.load_fbx("lucy.fbx", ""), fn(result) {
        case result {
          Ok(data) -> ModelLoaded(data)
          Error(error) -> LoadingFailed(error)
        }
      }),
    )

  #(
    Model(
      time: 0.0,
      p1: Player(id: P1, position: 0.0, speed: 1.0),
      p2: Player(id: P2, position: 0.0, speed: 1.0),
      ball: Ball(
        position: vec3.Vec3(0.0, 0.0, 0.0),
        rotation: 0.0,
        velocity: 0.2,
        direction: vec3.Vec3(1.0, 0.0, 0.0),
        owner: P1,
      ),
      game: Game(p1_score: 0, p2_score: 0),
      load_state: Loading,
      level: levels.get_random_level(),
      camera_type: levels.Static,
    ),
    effect.batch([effect.tick(Tick), load_effect]),
    option.None,
  )
}

fn player_move(player: Player, direction: Direction) -> Player {
  let dp = case direction {
    Forward -> 0.1
    Backward -> -0.1
  }
  let position = player.position +. dp *. player.speed |> float.clamp(-1.0, 1.0)
  Player(..player, position:)
}

fn ball_bounce(
  ball_position: vec3.Vec3(Float),
  player_position: vec3.Vec3(Float),
) {
  let #(ax, ay) = #(player_position.x, player_position.z)
  let #(bx, by) = #(ball_position.x, ball_position.z)
  let dx = { bx -. ax } |> float.clamp(-1.0, 1.0)
  // hack so the ball doesn't go vertical
  let dx = case dx >. -1.0, dx <. 1.0, dx >. 0.0 {
    True, True, True -> 1.0
    True, True, False -> -1.0
    _, _, _ -> dx
  }
  let dy = { by -. ay } *. 0.8

  let len_sq = dx *. dx +. dy *. dy
  case float.square_root(len_sq) {
    Ok(len) ->
      case len == 0.0 {
        True -> vec3.Vec3(0.0, 0.0, 0.0)
        False -> vec3.Vec3(dx /. len, 0.0, dy /. len)
      }
    Error(_) -> vec3.Vec3(0.0, 0.0, 0.0)
  }
}

fn update(
  model: Model,
  msg: Msg,
  ctx: tiramisu.Context(String),
) -> #(Model, Effect(Msg), option.Option(_)) {
  case msg {
    Tick -> {
      let new_p1 = case
        input.is_key_pressed(ctx.input, input.KeyW),
        input.is_key_pressed(ctx.input, input.KeyS)
      {
        True, False -> {
          player_move(model.p1, Backward)
        }
        False, True -> {
          player_move(model.p1, Forward)
        }
        _, _ -> model.p1
      }
      let new_p2 = case
        input.is_key_pressed(ctx.input, input.ArrowUp),
        input.is_key_pressed(ctx.input, input.ArrowDown)
      {
        True, False -> {
          player_move(model.p2, Backward)
        }
        False, True -> {
          player_move(model.p2, Forward)
        }
        _, _ -> model.p2
      }

      let p1_position = vec3.Vec3(-10.0, 0.0, 5.0 *. model.p1.position)

      let p1_bounds =
        p1_position
        |> spatial.collider_box_from_center(vec3.Vec3(0.5, 0.5, 2.5))

      let p2_position = vec3.Vec3(10.0, 0.0, 5.0 *. model.p2.position)

      let p2_bounds =
        p2_position
        |> spatial.collider_box_from_center(vec3.Vec3(0.5, 0.5, 2.5))

      let wall1_pos = vec3.Vec3(0.0, 0.0, 8.0)
      let wall1_bounds =
        wall1_pos |> spatial.collider_box_from_center(vec3.Vec3(10.0, 0.5, 0.5))

      let wall2 = vec3.Vec3(0.0, 0.0, -8.0)
      let wall2_bounds =
        wall2
        |> spatial.collider_box_from_center(vec3.Vec3(10.0, 0.5, 0.5))

      let ball_bounds = model.ball.position |> spatial.collider_sphere(0.5)

      let intersect_p1 = spatial.collider_intersects(p1_bounds, ball_bounds)
      let intersect_p2 = spatial.collider_intersects(p2_bounds, ball_bounds)

      let #(owner, direction, increase) = case
        intersect_p1,
        intersect_p2,
        model.ball.owner
      {
        _, True, P1 -> #(
          P2,
          ball_bounce(model.ball.position, p2_position),
          True,
        )
        True, _, P2 -> #(
          P1,
          ball_bounce(model.ball.position, p1_position),
          True,
        )
        _, _, _ -> {
          let intersect_w1 =
            spatial.collider_intersects(wall1_bounds, ball_bounds)
          let intersect_w2 =
            spatial.collider_intersects(wall2_bounds, ball_bounds)

          let dir = case intersect_w1, intersect_w2 {
            False, False -> {
              model.ball.direction
            }
            _, _ ->
              model.ball.direction |> vec3.map_z(fn(z) { 0.0 -. z }) |> echo
          }

          #(model.ball.owner, dir, False)
        }
      }

      let velocity = case increase {
        True -> model.ball.velocity +. 0.05
        False -> model.ball.velocity
      }

      let new_ball_position =
        model.ball.position
        |> vec3.map2(direction, fn(x, y) { x +. y *. model.ball.velocity })
      let rotation = model.ball.rotation +. 0.1 *. velocity

      let new_ball =
        Ball(
          owner:,
          velocity:,
          direction:,
          position: new_ball_position,
          rotation:,
        )

      let score1_pos = vec3.Vec3(14.0, 0.0, 0.0)
      let score1_bounds =
        score1_pos
        |> spatial.collider_box_from_center(vec3.Vec3(0.5, 0.5, 20.5))

      let score2_pos = vec3.Vec3(-14.0, 0.0, 0.0)
      let score2_bounds =
        score2_pos
        |> spatial.collider_box_from_center(vec3.Vec3(0.5, 0.5, 20.5))

      let intersect_s1 = spatial.collider_intersects(score1_bounds, ball_bounds)
      let intersect_s2 = spatial.collider_intersects(score2_bounds, ball_bounds)

      let #(game, new_ball, new_camera_type, new_time) = case
        intersect_s1,
        intersect_s2
      {
        True, _ -> #(
          Game(model.game.p1_score + 1, model.game.p2_score),
          Ball(
            owner: P2,
            direction: vec3.Vec3(-1.0, 0.0, 0.0),
            position: vec3.Vec3(0.0, 0.0, 0.0),
            velocity: 0.2,
            rotation: 0.0,
          ),
          levels.get_camera_type(model.camera_type),
          0.0,
        )
        _, True -> #(
          Game(model.game.p1_score, model.game.p2_score + 1),
          Ball(
            owner: P1,
            direction: vec3.Vec3(1.0, 0.0, 0.0),
            position: vec3.Vec3(0.0, 0.0, 0.0),
            velocity: 0.2,
            rotation: 0.0,
          ),
          levels.get_camera_type(model.camera_type),
          0.0,
        )
        _, _ -> #(
          model.game,
          new_ball,
          model.camera_type,
          model.time +. ctx.delta_time,
        )
      }

      #(
        Model(
          ..model,
          time: new_time,
          p1: new_p1,
          p2: new_p2,
          ball: new_ball,
          game:,
          camera_type: new_camera_type,
        ),
        effect.batch([
          effect.tick(Tick),
          ui.dispatch_to_lustre(UpdateScore(game.p1_score, game.p2_score)),
        ]),
        option.None,
      )
    }
    ModelLoaded(data) -> {
      let animation_count = data.animations |> list.length()
      io.println(
        "Loaded GLTF model with "
        <> int.to_string(animation_count)
        <> " animations",
      )
      #(Model(..model, load_state: Loaded(data)), effect.none(), option.None)
    }

    LoadingFailed(error) -> {
      let error_msg = case error {
        asset.LoadError(msg) -> "Load error: " <> msg
        asset.InvalidUrl(url) -> "Invalid URL: " <> url
        asset.ParseError(msg) -> "Parse error: " <> msg
      }
      io.println("Failed to load model: " <> error_msg)
      #(
        Model(..model, load_state: Failed(error_msg)),
        effect.none(),
        option.None,
      )
    }
  }
}

fn view(model: Model, _ctx: tiramisu.Context(String)) -> scene.Node(String) {
  let assert Ok(cam) =
    camera.perspective(field_of_view: 95.0, near: 0.1, far: 1000.0)
  let assert Ok(sphere_mat) =
    material.new() |> material.with_color(0x0066ff) |> material.build
  let assert Ok(player1_mat) =
    material.new() |> material.with_color(0x448080) |> material.build
  let assert Ok(player2_mat) =
    material.new() |> material.with_color(0x804480) |> material.build

  let assert Ok(wall_geom) = geometry.box(width: 1.0, height: 1.0, depth: 1.0)

  let lucy = case model.load_state {
    Loading -> {
      // Show a spinning cube while loading
      let loading_cube =
        scene.mesh(
          id: "loading_cube",
          geometry: {
            let assert Ok(geometry) =
              geometry.box(width: 1.0, height: 1.0, depth: 1.0)
            geometry
          },
          material: {
            let assert Ok(material) =
              material.phong(
                0x4ecdc4,
                30.0,
                option.None,
                option.None,
                option.None,
                transparent: False,
                opacity: 1.0,
                alpha_test: 0.0,
              )
            material
          },
          transform: transform.at(position: vec3.Vec3(0.0, 0.0, 0.0)),
          physics: option.None,
        )
      loading_cube
    }

    Failed(_error_msg) -> {
      // Show a red cube to indicate error
      let error_cube =
        scene.mesh(
          id: "error_cube",
          geometry: {
            let assert Ok(geometry) =
              geometry.box(width: 1.0, height: 1.0, depth: 1.0)
            geometry
          },
          material: {
            let assert Ok(material) =
              material.new()
              |> material.with_color(0xff0000)
              |> material.with_metalness(0.5)
              |> material.with_roughness(0.5)
              |> material.build()
            material
          },
          transform: transform.at(position: vec3.Vec3(0.0, 0.0, 0.0)),
          physics: option.None,
        )
      error_cube
    }

    Loaded(gltf_model) -> {
      let model_node =
        scene.model_3d(
          id: "lucy",
          object: gltf_model.scene,
          transform: transform.at(position: model.ball.position)
            |> transform.with_euler_rotation(vec3.Vec3(
              0.0,
              model.time *. model.ball.velocity /. 100.0,
              0.0,
            )),
          animation: option.None,
          physics: option.None,
          material: option.None,
        )
      model_node
    }
  }

  let cam_transform = levels.get_camera(model.camera_type, model.time)

  scene.empty(id: "Scene", transform: transform.identity, children: [
    scene.camera(
      id: "camera",
      camera: cam,
      transform: cam_transform,
      look_at: option.None,
      active: True,
      viewport: option.None,
      postprocessing: option.None,
    ),
    scene.light(
      id: "ambient",
      light: {
        let assert Ok(light) = light.ambient(color: 0xffffff, intensity: 2.8)
        light
      },
      transform: transform.identity,
    ),
    scene.light(
      id: "directional",
      light: {
        let assert Ok(light) =
          light.directional(color: 0xffffff, intensity: 0.8)
        light
      },
      transform: transform.at(position: vec3.Vec3(10.0, 10.0, 10.0)),
    ),
    // scene.mesh(
    //   id: "sphere",
    //   geometry: sphere_geom,
    //   material: sphere_mat,
    //   transform: transform.at(position: model.ball.position),
    //   physics: option.None,
    // ),
    // scene.mesh(
    //   id: "ground",
    //   geometry: ground_geom,
    //   material: ground_mat,
    //   transform: transform.at(position: vec3.Vec3(0.0, -2.0, 0.0))
    //     |> transform.with_euler_rotation(vec3.Vec3(
    //       -1.57,
    //       0.0,
    //       model.time /. 1000.0,
    //     )),
    //   physics: option.None,
    // ),
    scene.mesh(
      id: "p1",
      geometry: model.level.player_geom,
      material: player1_mat,
      transform: transform.at(position: vec3.Vec3(
        -10.0,
        0.0,
        5.0 *. model.p1.position,
      )),
      physics: option.None,
    ),
    scene.mesh(
      id: "p2",
      geometry: model.level.player_geom,
      material: player2_mat,
      transform: transform.at(position: vec3.Vec3(
        10.0,
        0.0,
        5.0 *. model.p2.position,
      )),
      physics: option.None,
    ),
    scene.mesh(
      id: "wall",
      geometry: wall_geom,
      material: sphere_mat,
      transform: transform.at(position: vec3.Vec3(0.0, 0.0, 8.0))
        |> transform.with_scale(vec3.Vec3(20.0, 1.0, 1.0)),
      physics: option.None,
    ),
    scene.mesh(
      id: "wall2",
      geometry: wall_geom,
      material: sphere_mat,
      transform: transform.at(position: vec3.Vec3(0.0, 0.0, -8.0))
        |> transform.with_scale(vec3.Vec3(20.0, 1.0, 1.0)),
      physics: option.None,
    ),
    lucy,
  ])
}
