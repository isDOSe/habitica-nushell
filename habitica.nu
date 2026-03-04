const USER_ID = "TU USER ID DE HABITICA"
const API_TOKEN = "TU API TOKEN DE HABITICA"
const CLIENT_ID = "123098123-14-234234-2343-NushellRPG"
const CACHE_FILE = "C:/Direccion_de_tu_archivo/habitica_stats.json"

# --- Ayudante Visual ---
def draw_bar [current: float, max: float, color: string, length: int = 20] {
    let percent = (if $max > 0 { $current / $max } else { 0 })
    let filled_len = (($percent * ($length | into float)) | math round | into int)
    let empty_len = ($length - $filled_len)
    
    let filled_part = ("" | fill -c "█" -w $filled_len)
    let empty_part = ("" | fill -c "░" -w $empty_len)
    
    let bar = (([
        (ansi $color), $filled_part, (ansi reset),
        (ansi reset), $empty_part # Cambiamos 'faint' por 'reset' o 'grey'
    ] | str join))
    
    return $"($bar) ($current | math round)/($max | math round)"
}

# --- Comandos Exportados ---

export def "todo update" [] {
    # 1. Preparamos los datos fuera del bloque
    let uid = $USER_ID
    let key = $API_TOKEN
    let cid = $CLIENT_ID
    let path = $CACHE_FILE

    # 2. Usamos 'job spawn' pasando las variables
    job spawn {
        try {
            http get -H { 
                "x-api-user": $uid, 
                "x-api-key": $key, 
                "x-client": $cid 
            } https://habitica.com/api/v3/user 
            | get data 
            | save -f $path
        } catch { }
    }
}

export def "todo stats" [] {
    if ($CACHE_FILE | path exists) {
        let s = (open $CACHE_FILE).stats
        
        # Conversiones seguras
        let hp = ($s.hp | into float)
        let max_hp = ($s.maxHealth | into float)
        let xp = ($s.exp | into float)
        let max_xp = ($s.toNextLevel | into float)
        let mp = ($s.mp | into float)
        let max_mp = ($s.maxMP | into float)

        print $"(ansi green_bold)--- ESTADO DEL HÉROE ---(ansi reset)"
        print $"HP:   (draw_bar $hp $max_hp 'red_bold')"
        print $"XP:   (draw_bar $xp $max_xp 'yellow_bold')"
        print $"MP:   (draw_bar $mp $max_mp 'cyan_bold')" # Barra de Maná en Cyan
        print $"ORO:  (ansi yellow)($s.gp | into float | math round --precision 2) GP(ansi reset)"
    } else {
        todo update
    }
}

export def "todo list" [] {
    let headers = { "x-api-user": $USER_ID, "x-api-key": $API_TOKEN, "x-client": $CLIENT_ID }
    let r = (http get -H $headers https://habitica.com/api/v3/tasks/user?type=todos)
    if ($r | get -o success) == true { 
        $r.data | where completed == false | select text id 
    }
}

export def "todo done" [id: string] {
    let headers = { "x-api-user": $USER_ID, "x-api-key": $API_TOKEN, "x-client": $CLIENT_ID }
    let r = (http post -H $headers $"https://habitica.com/api/v3/tasks/($id)/score/up")
    if ($r | get -o success) == true { 
        print "✅ ¡Tarea completada!"; todo update 
    }
}

export def "todo add" [text: string] {
    let headers = { "x-api-user": $USER_ID, "x-api-key": $API_TOKEN, "x-client": $CLIENT_ID }
    let body = { text: $text, type: "todo" }
    let r = (http post -H $headers --content-type application/json https://habitica.com/api/v3/tasks/user $body)
    if ($r | get -o success) == true { print $"✅ Creada: ($r.data.text)" }
}

def get_banner [] {
    let c = (ansi magenta_bold)
    let r = (ansi reset)
    
    # Usamos una sola cadena de texto para evitar errores de comandos vacíos
    let art = $"
($c)  ____   ___  ____  _____ 
($c) |  _ \\ / _ \\/ ___|| ____|
($c) | | | | | | \\___ \\|  _|  
($c) | |_| | |_| |___) | |___ 
($c) |____/ \\___/|____/|_____|"
    
    return $art
}

export def "todo welcome" [] {
    clear
    print (get_banner)
    print ""
    todo stats
    print ""

    # Verificamos si hay tareas antes de listar
    try {
        let tareas_hoy = (todo today)
        let cantidad = ($tareas_hoy | length)

        if $cantidad > 0 {
            print $"(ansi yellow_bold)¡Atención! Tienes ($cantidad) misiones para hoy(ansi reset)"
            #print $tareas_hoy
            #print $"(ansi blue_bold)Usa 'todo done <id>' para completarlas.(ansi reset)"
        } else {
            print $"(ansi green_bold)✨ ¡Todo despejado! No hay misiones para hoy. ¡A descansar, héroe!(ansi reset)"
            
            # Opcional: Un pequeño dibujo de una fogata o descanso
            print $"(ansi red)   (    (   (ansi reset)"
            print $"(ansi red)    )    )   (ansi reset)"
            print $"(ansi yellow)  [          ] (ansi reset)"
            print $"(ansi yellow)   \\________/ (ansi reset)"
        }
    } catch { }
}


export def "todo today" [] {
    let headers = ["x-api-user" $USER_ID "x-api-key" $API_TOKEN "x-client" $CLIENT_ID]
    
    # Obtenemos la fecha de hoy a medianoche para comparar solo días
    let hoy = (date now | format date "%Y-%m-%d")
    
    let r = (http get --headers $headers https://habitica.com/api/v3/tasks/user?type=todos)
    
    if ($r | get -o success) == true { 
        $r.data 
        | where completed == false 
        | filter {|t| 
            # Verificamos si tiene fecha y si esa fecha coincide con hoy
            if ($t.date? != null) {
                ($t.date | str substring 0..9) == $hoy
            } else {
                false
            }
        }
        | select text id 
    }
}

export def "todo spell use" [
    spell_idx: int     
    separator: string  
    task_idx: int      
] {
    # 1. BUSCAR EL HECHIZO
    let spells_list = (todo spell list)
    let spell_match = ($spells_list | where index == $spell_idx)
    
    if ($spell_match | is-empty) {
        print $"(ansi red_bold)Error: El hechizo #($spell_idx) no existe.(ansi reset)"
        return
    }
    let spell_info = ($spell_match | first)

    # 2. BUSCAR EN TODA LA LISTA
    # Aquí llamamos a la función que trae TODOS los To-Dos pendientes
    let todas_las_tareas = (todo list)
    
    if ($todas_las_tareas | is-empty) {
        print $"(ansi red_bold)Error: No tienes ninguna tarea pendiente en tu lista.(ansi reset)"
        return
    }

    # Buscamos por el índice de la tabla completa
    let task_match = ($todas_las_tareas | enumerate | where index == ($task_idx - 1))

    if ($task_match | is-empty) {
        let max = ($todas_las_tareas | length)
        print $"(ansi red_bold)Error: El índice ($task_idx) está fuera de rango (Máximo: ($max)).(ansi reset)"
        return
    }
    let task_info = ($task_match | first | get item)

    # 3. LANZAR EL HECHIZO
    print $"(ansi yellow)Lanzando ($spell_info.nombre) sobre ($task_info.text)...(ansi reset)"

    let headers = ["x-api-user" $USER_ID "x-api-key" $API_TOKEN "x-client" $CLIENT_ID]
    let url = $"https://habitica.com/api/v3/user/class/cast/($spell_info.id)?targetId=($task_info.id)"

    let r = (http post --headers $headers $url "{}") # Enviamos un body vacío ya que el ID va en la URL

    if ($r | get -o success) == true {
        print $"(ansi green_bold)⚔️¡Hechizo lanzado con éxito!(ansi reset)"
        todo update 
    } else {
        let msg = ($r | get -o message | default "Error desconocido")
        print $"(ansi red_bold)Error de Habitica: ($msg)(ansi reset)"
    }
}

export def "todo spell list" [] {
    if not ($CACHE_FILE | path exists) { todo update; return }
    let data = (open $CACHE_FILE)
    let clase = ($data.stats.class)
    let mp_actual = ($data.stats.mp)

    # Diccionario de hechizos por clase (puedes ampliarlo luego)
    let spells = {
        wizard: [
            [id, nombre, costo, desc];
            [fireball, "Bola de Fuego", 10, "Daño a jefes"]
            [mpheal, "Sobretensión Etérea", 30, "Restaura Maná"]
            [earth, "Terremoto", 35, "Daño a jefes (Int)"]
            [frost, "Escarcha", 40, "Congela rachas"]
        ],
        warrior: [
            [id, nombre, costo, desc];
            [smash, "Golpe Brutal", 10, "Daño a jefes"]
            [defensiveStance, "Postura Defensiva", 25, "Protege de daño"]
            [valorousPresence, "Presencia Valerosa", 20, "Bonus de Fuerza"]
        ],
        healer: [
            [id, nombre, costo, desc];
            [heal, "Curación", 15, "Sana HP"]
            [brightness, "Luminosidad", 15, "Bonus de Inteligencia"]
        ],
        rogue: [
            [id, nombre, costo, desc];
            [pickPocket, "Carterista", 15, "Gana Oro"]
            [backStab, "Puñalada", 15, "Daño y Oro"]
        ]
    }

    let mis_spells = ($spells | get -o $clase | enumerate | each {|s| 
        $s.item | insert index ($s.index + 1)
    })

    print $"(ansi cyan_bold)--- TUS HECHIZOS (($clase)) --- (ansi reset) Mana: ($mp_actual)"
    return $mis_spells
}