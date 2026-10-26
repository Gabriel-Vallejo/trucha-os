import QtQuick
import Quickshell
import qs.Services

// Competis — la pestaña de ciberseguridad y hackatones que tenías en COSMIC, ahora en el lanzador de DMS.
// Abre con "@" en el lanzador (⊞+Espacio) o directamente con ⊞+Shift+Espacio.
Item {
    id: root

    property var pluginService: null
    property string trigger: "@"

    signal itemsChanged()

    readonly property string home: "__HOME__"
    readonly property string kitty: home + "/.local/bin/kitty"
    readonly property string ctfDir: home + "/CTF"

    // tipo de acción:  app:<desktop-id> · term:<comando> · open:<ruta o url>
    readonly property var entries: [
        // ── Hacking ───────────────────────────────────────────────
        { name: "Ghidra", comment: "Reversing · decompilador", icon: home + "/.local/share/icons/ghidra.png", action: "app:ghidra" },
        { name: "Burp Suite", comment: "Web · proxy de interceptación", icon: home + "/BurpSuiteCommunity/.install4j/BurpSuiteCommunity.png", action: "app:install4j_19nqyou-BurpSuiteCommunity" },
        { name: "Wireshark", comment: "Redes · análisis de tráfico y pcaps", icon: "org.wireshark.Wireshark", action: "app:org.wireshark.Wireshark" },
        { name: "CyberChef", comment: "Cripto/encoding · offline (local)", icon: home + "/tools/CyberChef/images/cyberchef-128x128.png", action: "app:cyberchef-offline" },
        { name: "dCode.fr", comment: "Cripto · cifrados clásicos", icon: "material:key", action: "app:dcode-fr" },
        { name: "DBeaver", comment: "Bases de datos", icon: "io.dbeaver.DBeaverCommunity", action: "app:io.dbeaver.DBeaverCommunity" },

        // ── Terminal de CTF ───────────────────────────────────────
        { name: "Terminal CTF", comment: "kitty en ~/CTF", icon: "material:terminal", action: "term:" },
        { name: "pwndbg", comment: "Pwn · gdb + pwndbg", icon: "material:bug_report", action: "term:gdb -q" },
        { name: "pwntools", comment: "Pwn · Python con from pwn import *", icon: "material:memory", action: "term:python3 -ic 'from pwn import *'" },
        { name: "radare2", comment: "Reversing · r2", icon: "material:account_tree", action: "term:r2 -h | head -25" },
        { name: "Volatility 3", comment: "Forense · análisis de memoria", icon: "material:sd_card", action: "term:vol -h | head -30" },
        { name: "Sleuth Kit · binwalk · foremost", comment: "Forense · discos y carving", icon: "material:find_in_page", action: "term:echo 'fls · mmls · icat · binwalk -e · foremost -i'" },
        { name: "oletools", comment: "Forense · macros de Office (olevba)", icon: "material:description", action: "term:olevba -h | head -20" },
        { name: "steghide · exiftool", comment: "Estego · metadatos", icon: "material:image_search", action: "term:echo 'steghide extract -sf img · exiftool img · strings -n 8'" },
        { name: "RsaCtfTool", comment: "Cripto · ataques a RSA", icon: "material:lock_open", action: "term:RsaCtfTool -h | head -25" },
        { name: "SageMath", comment: "Cripto · Sage en Docker", icon: "material:functions", action: "term:sage" },
        { name: "hashcat", comment: "Cracking · GPU RTX 5070 (CUDA)", icon: "material:speed", action: "term:hashcat -I | head -12" },
        { name: "John the Ripper", comment: "Cracking · CPU", icon: "material:password", action: "term:john --list=build-info | head -5" },
        { name: "sqlmap", comment: "Web · inyección SQL", icon: "material:database", action: "term:sqlmap --version" },
        { name: "ffuf · gobuster", comment: "Web · fuzzing de rutas", icon: "material:travel_explore", action: "term:echo 'ffuf -u URL/FUZZ -w ~/tools/SecLists/Discovery/Web-Content/common.txt'" },
        { name: "nmap", comment: "Redes · escaneo", icon: "material:lan", action: "term:nmap --version" },
        { name: "yara · gitleaks", comment: "Detección · reglas y secretos", icon: "material:policy", action: "term:echo 'yara reglas.yar fichero · gitleaks detect -s repo'" },

        // ── Carpetas ──────────────────────────────────────────────
        { name: "SecLists", comment: "Carpeta · wordlists", icon: "folder-red", action: "open:" + home + "/tools/SecLists" },
        { name: "CTF", comment: "Carpeta · retos", icon: "folder-red", action: "open:" + home + "/CTF" },
        { name: "Descargas", comment: "Carpeta · materiales de la hackatón", icon: "folder-red-download", action: "open:" + home + "/Descargas" },

        // ── Webs de referencia ────────────────────────────────────
        { name: "HackTricks", comment: "Web · metodología", icon: "material:menu_book", action: "open:https://book.hacktricks.wiki/" },
        { name: "GTFOBins", comment: "Web · escalada con binarios", icon: "material:terminal", action: "open:https://gtfobins.github.io/" },
        { name: "RevShells", comment: "Web · generador de reverse shells", icon: "material:swap_horiz", action: "open:https://www.revshells.com/" },
        { name: "CrackStation", comment: "Web · hashes conocidos", icon: "material:tag", action: "open:https://crackstation.net/" },
        { name: "factordb", comment: "Web · factorizar N de RSA", icon: "material:calculate", action: "open:https://factordb.com/" },
        { name: "Exploit-DB", comment: "Web · exploits públicos", icon: "material:warning", action: "open:https://www.exploit-db.com/" },

        // ── Desarrollo ────────────────────────────────────────────
        { name: "kitty", comment: "Terminal", icon: home + "/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png", action: "app:kitty" },
        { name: "Visual Studio Code", comment: "Editor", icon: "vscode", action: "app:code" },
        { name: "PyCharm", comment: "JetBrains", icon: "jetbrains-pycharm-1a5c20b5-cbb8-486d-9e0d-4861af795236", action: "app:jetbrains-pycharm-1a5c20b5-cbb8-486d-9e0d-4861af795236" },
        { name: "IntelliJ IDEA", comment: "JetBrains", icon: "jetbrains-idea-c33a7fc0-247a-42d9-86d8-a90956d4a485", action: "app:jetbrains-idea-c33a7fc0-247a-42d9-86d8-a90956d4a485" },
        { name: "CLion", comment: "JetBrains", icon: "jetbrains-clion-fe88b80f-4a3e-4c00-b1cd-34cade00213b", action: "app:jetbrains-clion-fe88b80f-4a3e-4c00-b1cd-34cade00213b" },
        { name: "DataGrip", comment: "JetBrains", icon: "jetbrains-datagrip-8987bc10-d4a9-4655-9157-7f580fe7aa0b", action: "app:jetbrains-datagrip-8987bc10-d4a9-4655-9157-7f580fe7aa0b" },
        { name: "GoLand", comment: "JetBrains", icon: "jetbrains-goland-6611d89d-ce8d-42ca-8d60-af5f64e792bb", action: "app:jetbrains-goland-6611d89d-ce8d-42ca-8d60-af5f64e792bb" },
        { name: "WebStorm", comment: "JetBrains", icon: "jetbrains-webstorm-2cb3b369-942f-40e7-a227-a0609f328b97", action: "app:jetbrains-webstorm-2cb3b369-942f-40e7-a227-a0609f328b97" },
        { name: "DataSpell", comment: "JetBrains", icon: "jetbrains-dataspell-f08b7b3d-42f8-4318-8454-bc439d5f4eb1", action: "app:jetbrains-dataspell-f08b7b3d-42f8-4318-8454-bc439d5f4eb1" },
        { name: "Gateway", comment: "JetBrains · remoto", icon: "jetbrains-gateway-039f46c0-aaa0-4c8b-acbc-5b447d239cd7", action: "app:jetbrains-gateway-039f46c0-aaa0-4c8b-acbc-5b447d239cd7" },
        { name: "JetBrains Toolbox", comment: "JetBrains", icon: "jetbrains-toolbox", action: "app:jetbrains-toolbox" },
        { name: "Obsidian", comment: "Notas · Truchilla", icon: home + "/.local/share/icons/obsidian.png", action: "app:obsidian" },

        // ── Utilidades ────────────────────────────────────────────
        { name: "Firefox", comment: "Navegador", icon: "firefox", action: "app:firefox" },
        { name: "Google Chrome", comment: "Navegador", icon: "google-chrome", action: "app:google-chrome" },
        { name: "Thunderbird", comment: "Correo", icon: "thunderbird", action: "app:thunderbird" },
        { name: "Visor de documentos", comment: "PDF", icon: "org.gnome.Evince", action: "app:org.gnome.Evince" },
        { name: "Visor de imágenes", comment: "Imágenes", icon: "org.gnome.eog", action: "app:org.gnome.eog" },
        { name: "File Roller", comment: "Comprimidos", icon: "org.gnome.FileRoller", action: "app:org.gnome.FileRoller" },
        { name: "Mapa de caracteres", comment: "Unicode", icon: "accessories-character-map", action: "app:gucharmap" },
        { name: "Contraseñas y claves", comment: "Seahorse · GPG/SSH", icon: "org.gnome.seahorse.Application", action: "app:org.gnome.seahorse.Application" },
        { name: "Audacity", comment: "Audio · estego en espectrograma", icon: "audacity", action: "app:audacity" },
        { name: "LibreOffice Writer", comment: "Ofimática", icon: "libreoffice-writer", action: "app:libreoffice-writer" },
        { name: "LibreOffice Calc", comment: "Ofimática", icon: "libreoffice-calc", action: "app:libreoffice-calc" },
        { name: "LibreOffice Impress", comment: "Ofimática", icon: "libreoffice-impress", action: "app:libreoffice-impress" },
        { name: "xgps", comment: "GPS", icon: "/usr/local/share/gpsd/icons/gpsd-logo.png", action: "app:xgps" },
        { name: "xgpsspeed", comment: "GPS", icon: "/usr/local/share/gpsd/icons/gpsd-logo.png", action: "app:xgpsspeed" },
        { name: "HPE GreenLake", comment: "Web", icon: "applications-internet", action: "app:hpe-greenlake" },
        { name: "Captura de pantalla", comment: "Región (niri)", icon: "material:screenshot_region", action: "niri:screenshot" }
    ]

    function getItems(query) {
        const items = entries.map(e => Object.assign({ categories: ["Competis"] }, e));
        if (!query || query.length === 0)
            return items;
        const q = query.toLowerCase();
        return items.filter(i => i.name.toLowerCase().includes(q) || i.comment.toLowerCase().includes(q));
    }

    function executeItem(item) {
        if (!item || !item.action)
            return;
        const sep = item.action.indexOf(":");
        const type = item.action.substring(0, sep);
        const data = item.action.substring(sep + 1);

        switch (type) {
        case "app":
            Quickshell.execDetached(["gtk-launch", data]);
            break;
        case "term":
            // abre kitty en ~/CTF, ejecuta el comando y deja la shell abierta
            Quickshell.execDetached([kitty, "--directory", ctfDir, "bash", "-ic", (data ? data + "; " : "") + "exec bash"]);
            break;
        case "open":
            Quickshell.execDetached(["xdg-open", data]);
            break;
        case "niri":
            Quickshell.execDetached(["niri", "msg", "action", data]);
            break;
        }
    }
}
