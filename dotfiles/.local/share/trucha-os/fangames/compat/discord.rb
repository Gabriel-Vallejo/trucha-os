# discord.rb — precarga de trucha-fangames para juegos con el plugin de Discord Rich Presence.
# El plugin carga DiscordAPI_XP.dll con MiniFFI, que en Linux no existe; algunos juegos no lo protegen con
# rescue y se cierran al arrancar. Aquí esa DLL se cambia por un objeto que responde 0 a todo: el juego
# va igual, solo que sin estado en Discord.
class MiniFFI
  class << self
    alias_method :__trucha_new_original, :new

    def new(dll, *args)
      __trucha_new_original(dll, *args)
    rescue StandardError
      raise unless dll.to_s =~ /discord/i
      TruchaFFIVacio.new
    end
  end
end

class TruchaFFIVacio
  def call(*_args) = 0
end
