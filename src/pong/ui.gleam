import gleam/int
import lustre/attribute.{attribute, class}
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import pong/game
import tiramisu/ui

pub type UIModel {
  UIModel(game: game.Game, state: game.GameState)
}

pub type UIMsg {
  UpdateScore(Int, Int)
  StartSingle
  StartMulti
  Finish
  Restart
}

pub fn init_ui(_flags) {
  // Register with Tiramisu to receive game state updates
  #(UIModel(game: game.Game(0, 0), state: game.Start), ui.register_lustre())
}

pub fn update_ui(model: UIModel, msg: UIMsg) {
  case msg {
    UpdateScore(p1_score, p2_score) -> #(
      UIModel(game: game.Game(p1_score, p2_score), state: model.state),
      effect.none(),
    )
    StartSingle -> {
      #(
        UIModel(game: game.Game(0, 0), state: game.Playing),
        ui.dispatch_to_tiramisu(game.PlaySingle),
      )
    }
    StartMulti -> {
      #(
        UIModel(game: game.Game(0, 0), state: game.Playing),
        ui.dispatch_to_tiramisu(game.PlayMulti),
      )
    }
    Finish -> {
      #(UIModel(game: model.game, state: game.Finish), effect.none())
    }
    Restart -> {
      #(
        UIModel(game: game.Game(0, 0), state: game.Start),
        ui.dispatch_to_tiramisu(game.Restart),
      )
    }
  }
}

pub fn view_ui(model: UIModel) {
  case model.state {
    game.Start -> menu_overlay()
    game.Playing ->
      html.div([class("fixed top-0 left-0 w-full h-full pointer-events-none")], [
        html.div(
          [
            class(
              "absolute top-5 left-5 p-4 bg-black/60 rounded-[5px] text-white font-sans pointer-events-auto",
            ),
          ],
          [
            html.div([class("mb-2.5")], [
              element.text("P1 Score: " <> int.to_string(model.game.p1_score)),
            ]),
            html.div([class("mb-2.5")], [
              element.text("P2 Score: " <> int.to_string(model.game.p2_score)),
            ]),
          ],
        ),
      ])
    game.Finish -> finish_overlay(model)
  }
}

fn menu_overlay() {
  html.div(
    [
      class(
        "absolute top-0 left-0 w-full h-full flex items-center justify-center bg-black/80 pointer-events-auto",
      ),
    ],
    [
      html.div(
        [
          class(
            "p-10 bg-[#1e1e2e]/95 rounded-[10px] text-white font-sans text-center",
          ),
        ],
        [
          html.h1([class("m-0 mb-5")], [element.text("Trippy Pong")]),
          html.h2([class("m-0 mb-1")], [
            element.text("pong but the camera is on a bit of a trip"),
          ]),
          html.h2([class("m-0 mb-5")], [element.text("first to 5 wins")]),
          html.ul([class("text-left my-5 pl-5")], [
            html.li([], [element.text("P1: W, S")]),
            html.li([], [element.text("P2: Up, Down")]),
          ]),
          html.div([class("flex flex-col gap-2 justify-center my-5")], [
            html.button(
              [
                event.on_click(StartSingle),
                class(
                  "px-7 py-2 text-lg cursor-pointer bg-[#4ecdc4] text-white border-none rounded-[5px]",
                ),
              ],
              [element.text("SinglePlayer")],
            ),
            html.button(
              [
                event.on_click(StartMulti),
                class(
                  "px-7 py-2 text-lg cursor-pointer bg-[#4ecdc4] text-white border-none rounded-[5px]",
                ),
              ],
              [element.text("MultiPlayer")],
            ),
          ]),
        ],
      ),
    ],
  )
}

fn finish_overlay(model: UIModel) {
  html.div(
    [
      class(
        "absolute top-0 left-0 w-full h-full flex items-center justify-center bg-black/80 pointer-events-auto",
      ),
    ],
    [
      html.div(
        [
          class(
            "p-10 bg-[#1e1e2e]/95 rounded-[10px] text-white font-sans text-center",
          ),
        ],
        [
          html.div([class("mb-2.5")], [
            case model.game.p1_score {
              5 -> element.text("P1 Wins!")
              _ -> element.text("P2 Wins!")
            },
          ]),
          html.div([class("flex flex-col gap-2 justify-center my-5")], [
            html.button(
              [
                event.on_click(Restart),
                class(
                  "px-7 py-2 text-lg cursor-pointer bg-[#4ecdc4] text-white border-none rounded-[5px]",
                ),
              ],
              [element.text("Restart")],
            ),
          ]),
        ],
      ),
    ],
  )
}

pub fn dispatch(game: game.Game) {
  ui.dispatch_to_lustre(UpdateScore(game.p1_score, game.p2_score))
}

pub fn finish() {
  ui.dispatch_to_lustre(Finish)
}
