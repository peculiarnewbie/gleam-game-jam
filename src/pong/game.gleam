import tiramisu/asset

pub type Game {
  Game(p1_score: Int, p2_score: Int)
}

pub type GameState {
  Start
  Playing
  Finish
}

pub type Msg {
  Tick
  ModelLoaded(asset.FBXData)
  LoadingFailed(asset.LoadError)
  PlaySingle
  PlayMulti
  Restart
}
