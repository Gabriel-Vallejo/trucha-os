# ruby18.rb — precarga de trucha-fangames para Essentials muy antiguos (Ruby 1.8).
# mkxp-z evalúa cada script con Kernel#eval; aquí se arreglan, antes de evaluarlos, dos cosas que Ruby 1.8
# aceptaba y Ruby 3 no:
#  · regex con bytes sueltos, /[\x7f-\x9f]/ («invalid multibyte escape»): se les añade /n, que es lo que eran.
#  · un `next` suelto en un método («Invalid next»): en 1.8 salía del método, así que pasa a `return`.
#  · `io.read(1)[0]`: en 1.8 daba el byte (un número); en Ruby 3 da un String, así que pasa a getbyte(0).
# No toca nada más del script.
module Kernel
  alias_method :__trucha_eval_original, :eval
  REGEX_BYTES = %r{(/(?:[^/\n\\]|\\.)*\\x[89a-fA-F][0-9a-fA-F](?:[^/\n\\]|\\.)*/)([imx]*)}
  NEXT_SUELTO = /:(\d+): Invalid next/

  def eval(src, binding = nil, *rest)
    if src.is_a?(String)
      src = src.gsub(REGEX_BYTES) { $2.include?("n") ? $& : "#{$1}#{$2}n" } if src.include?('\x')
      src = src.gsub(/\.read\(1\)\[0\]/, ".read(1).getbyte(0)")
    end
    intentos = 0
    begin
      # sin binding, el script tiene que vivir en el nivel superior y no dentro de este método
      __trucha_eval_original(src, binding || TOPLEVEL_BINDING, *rest)
    rescue SyntaxError => e
      linea = e.message[NEXT_SUELTO, 1]
      raise unless linea && src.is_a?(String) && (intentos += 1) <= 50
      lineas = src.lines
      lineas[linea.to_i - 1] = lineas[linea.to_i - 1].sub(/\bnext\b/, "return")
      src = lineas.join
      retry
    end
  end
  module_function :eval
  public :eval
end

# Thread.critical existía en Ruby 1.8 (sección crítica); con el GVL de Ruby 3 no hace falta: no hace nada.
class Thread
  def self.critical = false
  def self.critical=(_valor); end
end

# Los Essentials antiguos redefinen String#getbyte/#setbyte con la semántica de 1.8 (self[i]), que en Ruby 3
# devuelve un String en vez del byte. Un módulo antepuesto (prepend) gana a esas redefiniciones del juego.
module TruchaBytesNativos
  GETBYTE = String.instance_method(:getbyte)
  SETBYTE = String.instance_method(:setbyte)
  def getbyte(i) = GETBYTE.bind_call(self, i)
  def setbyte(i, b) = SETBYTE.bind_call(self, i, b)
end
String.prepend(TruchaBytesNativos)
