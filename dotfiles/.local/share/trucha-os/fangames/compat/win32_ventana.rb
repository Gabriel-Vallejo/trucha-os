# win32_ventana.rb — precarga de trucha-fangames que completa el win32_wrap.rb de mkxp-z.
# Los Essentials antiguos buscan la ventana «RGSS Player» con FindWindowEx y comparan el hilo dueño;
# en Linux no hay HWND, así que se finge una ventana (42, la misma que usa win32_wrap) y un único hilo.
# Va después de win32_wrap.rb, que define Win32API_Impl y memcpy_string.
module Win32API_Impl
  module Kernel32
    class GetCurrentThreadId
      def call(_args) = 1
    end
    class GetCurrentProcessId
      def call(_args) = 1
    end
  end

  module User32
    class FindWindowEx
      def call(args)
        anterior, clase = args[1], args[2]
        anterior.to_i.zero? && clase.to_s.start_with?("RGSS Player") ? 42 : 0
      end
    end
    FindWindowExA = FindWindowEx

    class GetWindowThreadProcessId
      def call(args)
        memcpy_string(args[1], [1].pack("l")) if args[1].is_a?(String)
        1
      end
    end

    class GetWindowRect
      def call(args)
        return 0 if args[0] != 42
        memcpy_string(args[1], [0, 0, Graphics.width, Graphics.height].pack("l4"))
        1
      end
    end

    class ClientToScreen
      def call(_args) = 1
    end

    class SetWindowPos
      def call(_args) = 1   # la ventana la coloca el compositor; mkxp-z ya escala el juego
    end

    class SetWindowTextA
      def call(_args) = 1
    end
    SetWindowText = SetWindowTextA
  end
end

# Algunos Essentials antiguos redefinen String#setbyte a su manera de Ruby 1.8 (con []=) y eso rompe el
# memcpy_string de win32_wrap; se guarda el original ahora, antes de que carguen los scripts del juego.
SETBYTE_ORIGINAL = String.instance_method(:setbyte)
def memcpy_string(dst, src)
  src.each_byte.with_index { |b, i| SETBYTE_ORIGINAL.bind_call(dst, i, b) }
end

# Algunos juegos redefinen Input.press? con GetAsyncKeyState; el ratón de win32_wrap llama a Input.press? y se
# metía en el del juego (bucle o nil). Se usa el Input.press? nativo de mkxp-z, guardado antes de los scripts.
INPUT_PRESS_NATIVO = Input.method(:press?)
alias __trucha_common_keystate_original common_keystate
def common_keystate(vkey)
  raton = { LBUTTON: Input::MOUSELEFT, RBUTTON: Input::MOUSERIGHT, MBUTTON: Input::MOUSEMIDDLE }[Scancodes::WIN32INV[vkey]]
  return INPUT_PRESS_NATIVO.call(raton) ? 1 : 0 if raton
  __trucha_common_keystate_original(vkey)
end

module Win32API_Impl
  module User32
    class GetForegroundWindow
      def call(_args) = 42   # la ventana del juego es la que tiene el foco: si no, el juego ignora el teclado
    end
    GetActiveWindow = GetForegroundWindow
  end
end
