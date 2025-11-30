import gleam/int
import gleam/option
import gleam_community/maths
import tiramisu/geometry
import tiramisu/transform
import vec/vec3

pub type Level {
  Level(player_geom: geometry.Geometry)
}

pub fn get_random_level() {
  let num = int.random(10)
  let assert Ok(player_geom) = geometry.box(width: 0.5, height: 0.5, depth: 5.0)
  Level(player_geom:)
}

pub type CameraType {
  Static
  Rotate
  Revolve
  Bounce
}

pub fn get_camera_type(old_type: CameraType) {
  let new_type = case int.random(4) {
    0 -> Rotate
    1 -> Revolve
    2 -> Bounce
    _ -> Static
  }

  case new_type == old_type {
    True -> get_camera_type(new_type)
    False -> new_type
  }
}

pub fn get_camera(cam: CameraType, time: Float) {
  case cam {
    Static -> {
      transform.at(position: vec3.Vec3(0.0, 10.0, 0.0))
      |> transform.with_euler_rotation(vec3.Vec3(-1.57, 0.0, 0.0))
    }
    Rotate -> {
      transform.at(position: vec3.Vec3(0.0, 10.0, 0.0))
      |> transform.with_euler_rotation(vec3.Vec3(-1.57, 0.0, time *. 0.001))
    }
    Revolve -> {
      transform.at(position: vec3.Vec3(
        0.0,
        maths.sin(1.57 +. { time /. 1000.0 }) *. 10.0,
        maths.cos(1.57 +. { time /. 1000.0 }) *. 10.0,
      ))
      |> transform.with_euler_rotation(vec3.Vec3(
        -1.57 +. time *. -0.001,
        0.0,
        0.0,
      ))
    }
    Bounce -> {
      transform.at(position: vec3.Vec3(
        0.0,
        10.0 +. maths.sin(time /. 1000.0) *. 5.0,
        0.0,
      ))
      |> transform.with_euler_rotation(vec3.Vec3(-1.57, 0.0, 0.0))
    }
  }
}
