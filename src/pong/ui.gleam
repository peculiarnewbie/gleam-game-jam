import gleam/int
import lustre/attribute.{attribute, class}
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import pong/game
import tiramisu/ui

pub type UIModel {
  UIModel(state: game.Game)
}

pub type UIMsg {
  UpdateScore(Int, Int)
}

pub fn init_ui(_flags) {
  // Register with Tiramisu to receive game state updates
  #(UIModel(game.Game(0, 0)), ui.register_lustre())
}

pub fn update_ui(_: UIModel, msg: UIMsg) {
  case msg {
    UpdateScore(p1_score, p2_score) -> #(
      UIModel(state: game.Game(p1_score, p2_score)),
      effect.none(),
    )
  }
}

pub fn view_ui(model: UIModel) -> Element(UIMsg) {
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

pub fn dispatch(game: game.Game) {
  ui.dispatch_to_lustre(UpdateScore(game.p1_score, game.p2_score))
}
