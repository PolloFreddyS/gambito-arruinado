class_name GameData
extends RefCounted
## Contenido del juego: reliquias, pergaminos, encantamientos y jefes.

const RELICS := {
	"caballo_borracho": {"name": "Caballo Borracho", "icon": "♞", "price": 6, "desc": "Tus caballos también saltan 3+1. Capturar con caballo: +20 puntos."},
	"sindicato": {"name": "Sindicato de Peones", "icon": "♟", "price": 5, "desc": "+1 Mult por cada 2 peones tuyos vivos."},
	"corona_prestada": {"name": "Corona Prestada", "icon": "♚", "price": 7, "desc": "Tu rey se mueve como una dama."},
	"sacrificio": {"name": "Sacrificio Sagrado", "icon": "✝", "price": 6, "desc": "Cuando pierdes una pieza, tu próxima captura vale ×3."},
	"coronacion_expres": {"name": "Coronación Exprés", "icon": "♛", "price": 5, "desc": "Tus peones coronan dos filas antes."},
	"contrato_maldito": {"name": "Contrato Maldito", "icon": "☠", "price": 8, "desc": "×2 Mult en todo, pero tienes 3 jugadas menos por combate."},
	"torre_vengativa": {"name": "Torre Vengativa", "icon": "♜", "price": 5, "desc": "Capturar con torre: +3 Mult."},
	"alfil_ambidiestro": {"name": "Alfil Ambidiestro", "icon": "♝", "price": 5, "desc": "Tus alfiles también se mueven 1 casilla en recto."},
	"hambre_peon": {"name": "Hambre de Peón", "icon": "♙", "price": 6, "desc": "Capturar con peón: ×3 Mult."},
	"racha_infinita": {"name": "Racha Infinita", "icon": "∞", "price": 8, "desc": "Mover sin capturar ya no rompe tu racha. Solo se rompe si pierdes una pieza."},
	"banco": {"name": "Banco del Peón", "icon": "$", "price": 5, "desc": "El interés máximo sube de 5 a 10 de oro."},
	"chocolate": {"name": "Moneda de Chocolate", "icon": "●", "price": 4, "desc": "+3 de oro al ganar cada combate."},
	"reloj_arena": {"name": "Reloj de Arena", "icon": "⌛", "price": 6, "desc": "+2 jugadas por combate."},
	"dama_furiosa": {"name": "Dama Furiosa", "icon": "♕", "price": 6, "desc": "Capturar con dama: +60 puntos."},
	"jaque_picante": {"name": "Jaque Picante", "icon": "⚡", "price": 6, "desc": "Cada jaque que das suma +2 Mult para el resto del combate."},
	"kamikaze": {"name": "Peones Kamikaze", "icon": "✹", "price": 7, "desc": "Si te capturan un peón, explota y destruye a los enemigos de al lado (y te dan puntos)."},
	"lupa": {"name": "Lupa del Tasador", "icon": "◎", "price": 7, "desc": "Todas las piezas enemigas valen +50% de puntos."},
	"gemelos": {"name": "Gemelos", "icon": "✌", "price": 5, "desc": "Tu primera captura de cada combate vale ×2."},
	"huracan": {"name": "Ojo del Huracán", "icon": "◉", "price": 7, "desc": "+1 Mult por cada 3 capturas en el combate."},
	"rey_guerrero": {"name": "Rey Guerrero", "icon": "⚔", "price": 6, "desc": "Capturar con el rey: ×4 Mult. (Arriesgado...)"},
}

const SCROLLS := {
	"bomba": {"name": "Bomba", "icon": "✹", "price": 4, "desc": "Elige una casilla: destruye a los enemigos en un área 3×3 (menos el rey) y suma sus puntos."},
	"congelar": {"name": "Congelar", "icon": "❄", "price": 3, "desc": "Elige una pieza enemiga: no se mueve por 3 turnos."},
	"reloj": {"name": "Reloj de Bolsillo", "icon": "⌛", "price": 3, "desc": "+3 jugadas en este combate."},
	"coronar": {"name": "Coronar", "icon": "♛", "price": 4, "desc": "Elige uno de tus peones: se vuelve dama ya."},
	"doble": {"name": "Doble Turno", "icon": "»", "price": 3, "desc": "Tu próxima jugada no deja responder al enemigo."},
}

const ENCHANTS := {
	"vidrio": {"name": "Pieza de Vidrio", "icon": "◇", "price": 5, "desc": "Sus capturas valen ×2 Mult, pero tiene 25% de romperse al capturar."},
	"oro": {"name": "Pieza de Oro", "icon": "◆", "price": 4, "desc": "Si sobrevive al combate, te da +3 de oro."},
	"explosiva": {"name": "Pieza Explosiva", "icon": "✸", "price": 6, "desc": "Cuando captura, explota y destruye a los enemigos de al lado (menos el rey)."},
}

const BOSSES := {
	"niebla": {"name": "La Reina de la Niebla", "desc": "Solo ves las casillas que tus piezas atacan o tocan."},
	"torre_eterna": {"name": "La Torre Eterna", "desc": "Sus torres reviven 2 turnos después de caer."},
	"plaga": {"name": "La Plaga", "desc": "Cada 4 jugadas, uno de tus peones se pasa al enemigo."},
	"tablero_vivo": {"name": "El Tablero Vivo", "desc": "Cada 3 turnos se marcan 3 casillas que explotan en lava al turno siguiente."},
	"duplicador": {"name": "El Duplicador", "desc": "Cada 3 turnos, el enemigo mueve dos veces seguidas."},
	"cobrador": {"name": "El Cobrador", "desc": "Cada jugada sin captura te cuesta 1 de oro."},
	"rey_cobarde": {"name": "El Rey Cobarde", "desc": "Cuando le das jaque, su rey se teletransporta lejos (cada 3 turnos)."},
	"hereje": {"name": "El Obispo Hereje", "desc": "Las capturas en casillas oscuras valen la mitad de puntos."},
	"tormenta": {"name": "Tormenta Eléctrica", "desc": "Cada 3 turnos caen 2 rayos sobre piezas al azar de los dos bandos (menos los reyes)."},
	"terremoto": {"name": "Terremoto", "desc": "El tablero empieza agrietado: hay hoyos por donde nadie puede pasar."},
	"gran_maestro": {"name": "El Gran Maestro", "desc": "Jefe final. No se equivoca, mueve doble cada 3 turnos y sus torres reviven."},
}

const PIECE_PRICE := {1: 2, 2: 4, 3: 4, 4: 6, 5: 9}
const PIECE_ICON := {1: "♟", 2: "♞", 3: "♝", 4: "♜", 5: "♛", 6: "♚"}
const STAGE_NAMES: Array[String] = ["Escaramuza", "Batalla", "Jefe"]
