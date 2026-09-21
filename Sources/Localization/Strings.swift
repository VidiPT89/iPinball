import Foundation

/// Every piece of text in the app, in Portuguese (PT-PT) and English.
///
/// The language is a choice the player makes inside the game, not something
/// inherited from the system locale, so the strings live here instead of in
/// `Localizable.strings`. Split into small tables to keep type-checking quick.
enum Strings {

    typealias Pair = (pt: String, en: String)

    static let all: [String: Pair] = {
        var table: [String: Pair] = [:]
        for group in [common, menu, hud, missions, settings, gameOver, highScores, howTo, about, a11y] {
            table.merge(group) { _, new in new }
        }
        return table
    }()

    static let common: [String: Pair] = [
        "common.cancel": ("Cancelar", "Cancel"),
        "common.close": ("Fechar", "Close"),
    ]

    static let menu: [String: Pair] = [
        "menu.tagline": ("Mesa de arcade em néon", "A neon arcade table"),
        "menu.play": ("Jogar", "Play"),
        "menu.highScores": ("Recordes", "High Scores"),
        "menu.howToPlay": ("Como jogar", "How to Play"),
        "menu.settings": ("Definições", "Settings"),
        "menu.about": ("Sobre", "About"),
    ]

    static let hud: [String: Pair] = [
        "hud.score": ("Pontos", "Score"),
        "hud.ball": ("Bola", "Ball"),
        "hud.best": ("Melhor", "Best"),
        "hud.multiplier": ("Multiplicador", "Multiplier"),
        "hud.ballSave": ("Bola salva", "Ball Save"),
        "hud.launch": ("Arrasta para baixo e larga para lançar",
                       "Drag down and release to launch"),
        "hud.launchKeyboard": ("Mantém o espaço e larga para lançar",
                               "Hold space and release to launch"),
        "hud.tilt": ("TILT", "TILT"),
        "hud.tiltWarning": ("CUIDADO", "CAREFUL"),
        "hud.multiball": ("MULTIBOLA", "MULTIBALL"),
        "hud.jackpot": ("JACKPOT", "JACKPOT"),
        "hud.superJackpot": ("SUPER JACKPOT", "SUPER JACKPOT"),
        "hud.ballSaved": ("BOLA SALVA", "BALL SAVED"),
        "hud.extraBall": ("BOLA EXTRA", "EXTRA BALL"),
        "hud.bonus": ("BÓNUS", "BONUS"),
        "hud.lastBall": ("ÚLTIMA BOLA", "LAST BALL"),
        "hud.missionComplete": ("MISSÃO COMPLETA", "MISSION COMPLETE"),
        "hud.missionFailed": ("MISSÃO FALHADA", "MISSION FAILED"),
        "hud.wizard": ("MODO FINAL", "WIZARD MODE"),
    ]

    static let missions: [String: Pair] = [
        "mission.warmUp.name": ("Aquecimento", "Warm-Up"),
        "mission.warmUp.goal": ("Acerta em 5 bumpers", "Hit 5 pop bumpers"),
        "mission.rampRush.name": ("Corrida de Rampas", "Ramp Rush"),
        "mission.rampRush.goal": ("Completa 4 rampas", "Complete 4 ramps"),
        "mission.targetFrenzy.name": ("Frenesim de Alvos", "Target Frenzy"),
        "mission.targetFrenzy.goal": ("Derruba o banco sem perder a bola",
                                      "Clear the bank without draining"),
        "mission.orbitLoop.name": ("Volta Completa", "Orbit Loop"),
        "mission.orbitLoop.goal": ("Faz 3 orbits", "Complete 3 orbits"),
        "mission.lock3.name": ("Prender 3", "Lock 3"),
        "mission.lock3.goal": ("Prende 3 bolas nos saucers", "Lock 3 balls in the saucers"),
        "mission.jackpotHunt.name": ("Caça ao Jackpot", "Jackpot Hunt"),
        "mission.jackpotHunt.goal": ("Acerta no alvo aceso", "Hit the lit target"),
        "mission.finalShot.name": ("Tiro Final", "Final Shot"),
        "mission.finalShot.goal": ("Tudo aceso, 60 segundos", "Everything lit, 60 seconds"),
    ]

    static let settings: [String: Pair] = [
        "settings.title": ("Definições", "Settings"),
        "settings.language": ("Idioma", "Language"),
        "settings.appearance": ("Aspeto", "Appearance"),
        "settings.theme.system": ("Sistema", "System"),
        "settings.theme.light": ("Claro", "Light"),
        "settings.theme.dark": ("Escuro", "Dark"),
        "settings.audio": ("Áudio", "Audio"),
        "settings.sound": ("Efeitos sonoros", "Sound effects"),
        "settings.music": ("Música", "Music"),
        "settings.haptics": ("Vibração", "Haptics"),
        "settings.controls": ("Controlos", "Controls"),
        "settings.leftHanded": ("Disposição para canhotos", "Left-handed layout"),
        "settings.leftHanded.hint": ("Troca os lados dos flippers",
                                     "Swaps which side works which flipper"),
        "settings.autoPlunge": ("Lançamento automático", "Auto-plunge"),
        "settings.autoPlunge.hint": ("A bola parte sozinha", "The ball launches on its own"),
        "settings.game": ("Jogo", "Game"),
        "settings.balls": ("Bolas por partida", "Balls per game"),
        "settings.data": ("Dados", "Data"),
        "settings.resetScores": ("Apagar recordes", "Clear high scores"),
        "settings.resetConfirm": ("Apagar todos os recordes e estatísticas?",
                                  "Clear all high scores and stats?"),
    ]

    static let gameOver: [String: Pair] = [
        "gameover.title": ("Fim de jogo", "Game Over"),
        "gameover.score": ("Pontuação final", "Final score"),
        "gameover.best": ("Melhor de sempre", "All-time best"),
        "gameover.missions": ("Missões completas", "Missions completed"),
        "gameover.newHighScore": ("NOVO RECORDE", "NEW HIGH SCORE"),
        "gameover.initials": ("As tuas iniciais", "Your initials"),
        "gameover.save": ("Guardar", "Save"),
        "gameover.playAgain": ("Jogar outra vez", "Play again"),
        "gameover.menu": ("Menu principal", "Main menu"),
        "gameover.share": ("Partilhar", "Share"),
        "gameover.shareText": ("Fiz %@ pontos no iPinball.", "I scored %@ in iPinball."),
        "pause.title": ("Em pausa", "Paused"),
        "pause.resume": ("Retomar", "Resume"),
        "pause.restart": ("Recomeçar", "Restart"),
        "pause.menu": ("Sair para o menu", "Quit to menu"),
    ]

    static let highScores: [String: Pair] = [
        "highscores.title": ("Recordes", "High Scores"),
        "highscores.empty": ("Ainda não há recordes. Joga uma partida.",
                             "No scores yet. Go and play a game."),
        "highscores.stats": ("Estatísticas", "Lifetime stats"),
        "highscores.games": ("Partidas", "Games"),
        "highscores.balls": ("Bolas", "Balls"),
        "highscores.jackpots": ("Jackpots", "Jackpots"),
        "highscores.bestCombo": ("Melhor combo", "Best combo"),
        "highscores.playTime": ("Tempo de jogo", "Time played"),
    ]

    static let howTo: [String: Pair] = [
        "howto.title": ("Como jogar", "How to Play"),
        "howto.basics.title": ("O básico", "The basics"),
        "howto.basics.body": (
            "Tens 3 bolas por partida, ou 5 se mudares nas Definições. Arrasta para baixo e larga para lançar. Mantém a bola viva com os flippers e faz pontos em tudo o que acertares.",
            "You get 3 balls a game, or 5 if you change it in Settings. Drag down and release to launch. Keep the ball alive with the flippers and score off everything you hit."),
        "howto.controls.title": ("Controlos", "Controls"),
        "howto.controls.body": (
            "Toca na metade esquerda ou direita do ecrã para o flipper desse lado. O terço de cima da metade esquerda ativa o flipper superior. Um deslize horizontal curto abana a mesa. No Mac: setas esquerda e direita para os flippers, seta para cima para o superior, espaço para lançar, N e M para abanar.",
            "Tap the left or right half of the screen for that flipper. The top third of the left half works the upper flipper. A short horizontal swipe nudges the table. On the Mac: left and right arrows for the flippers, up arrow for the upper one, space to launch, N and M to nudge."),
        "howto.tilt.title": ("Abanar e tilt", "Nudge and tilt"),
        "howto.tilt.body": (
            "Abanar desvia a bola, mas três abanões em dois segundos dão TILT: perdes os flippers e a bola.",
            "Nudging shifts the ball, but three nudges in two seconds cause a TILT: you lose the flippers and the ball."),
        "howto.combos.title": ("Combos e multiplicadores", "Combos and multipliers"),
        "howto.combos.body": (
            "Rampas e orbits seguidas em menos de 4 segundos sobem o combo até 8×. Completar as pistas P-I-N-B sobe o multiplicador de jogador até 5×.",
            "Back-to-back ramps and orbits within 4 seconds build the combo up to 8×. Completing the P-I-N-B lanes raises the player multiplier up to 5×."),
        "howto.missions.title": ("Missões", "Missions"),
        "howto.missions.body": (
            "Acerta num saucer para começar uma missão. Completa as seis para desbloquear o Tiro Final. A missão Prender 3 lança a multibola, onde tudo vale a dobrar.",
            "Shoot a saucer to start a mission. Complete all six to unlock Final Shot. The Lock 3 mission starts multiball, where everything scores double."),
        "howto.save.title": ("Bola salva", "Ball save"),
        "howto.save.body": (
            "Os primeiros 8 segundos de cada bola estão protegidos. Se drenares nesse tempo, a bola volta.",
            "The first 8 seconds of every ball are covered. Drain in that window and the ball comes back."),
        "howto.scoring.title": ("Pontuação", "Scoring"),
        "howto.score.bumper": ("Bumper", "Pop bumper"),
        "howto.score.target": ("Alvo fixo", "Standup target"),
        "howto.score.dropTarget": ("Alvo rebatível", "Drop target"),
        "howto.score.ramp": ("Rampa", "Ramp"),
        "howto.score.orbit": ("Orbit", "Orbit"),
        "howto.score.laneSet": ("P-I-N-B completo", "P-I-N-B complete"),
        "howto.score.jackpot": ("Jackpot", "Jackpot"),
        "howto.score.superJackpot": ("Super jackpot", "Super jackpot"),
    ]

    static let about: [String: Pair] = [
        "about.title": ("Sobre", "About"),
        "about.developedBy": ("Developed by David Arsénio Martins",
                              "Developed by David Arsénio Martins"),
        "about.website": ("Site", "Website"),
        "about.github": ("GitHub", "GitHub"),
        "about.version": ("Versão", "Version"),
        "about.credits": ("Feito em Cascais, Portugal.", "Made in Cascais, Portugal."),
    ]

    static let a11y: [String: Pair] = [
        "a11y.leftFlipper": ("Flipper esquerdo", "Left flipper"),
        "a11y.rightFlipper": ("Flipper direito", "Right flipper"),
        "a11y.upperFlipper": ("Flipper superior", "Upper flipper"),
        "a11y.plunger": ("Lançador", "Plunger"),
        "a11y.pause": ("Pausar o jogo", "Pause the game"),
        "a11y.scoreValue": ("Pontuação: %@", "Score: %@"),
        "a11y.ballValue": ("Bola %d de %d", "Ball %d of %d"),
        "a11y.languageToggle": ("Mudar idioma", "Switch language"),
        "a11y.openWebsite": ("Abrir ividi.dev", "Open ividi.dev"),
        "a11y.openGitHub": ("Abrir GitHub", "Open GitHub"),
        "a11y.laneLit": ("Pista %@ acesa", "Lane %@ lit"),
        "a11y.laneOff": ("Pista %@ apagada", "Lane %@ off"),
    ]
}
