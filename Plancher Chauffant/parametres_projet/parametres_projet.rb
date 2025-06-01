require 'sketchup.rb'
require 'json'

module ParametresProjet
  PLUGIN_NAME = "Paramètres du projet"
  DICTIONARY = "ParametresProjet"
  TEMP_EXT_DEFAULT = -5.0
  COEF_SECURITE_DEFAULT = 15.0

  def self.afficher_dialogue
    model = Sketchup.active_model
    dict = model.attribute_dictionary(DICTIONARY, true)

    @dialog ||= UI::HtmlDialog.new(
      dialog_title: PLUGIN_NAME,
      preferences_key: "com.mondomaine.parametres_projet",
      scrollable: true,
      resizable: true,
      width: 450,
      height: 700,
      style: UI::HtmlDialog::STYLE_DIALOG
    )

    html_path = File.join(File.dirname(__FILE__), "interface_projet.html")
    unless File.exist?(html_path)
      UI.messagebox("Erreur : Fichier interface_projet.html introuvable")
      return
    end

    @dialog.set_file(html_path)

    # Callback pour enregistrer les paramètres
    @dialog.add_action_callback("enregistrer_params") do |_dlg, json_params|
      begin
        data = JSON.parse(json_params)
        
        # Validation des données
        unless data.key?("temp_ext")
          data["temp_ext"] = TEMP_EXT_DEFAULT
        else
          temp_ext = data["temp_ext"].to_f
          if temp_ext < -30 || temp_ext > 10
            UI.messagebox("Température extérieure invalide. Valeur réinitialisée à #{TEMP_EXT_DEFAULT}°C")
            data["temp_ext"] = TEMP_EXT_DEFAULT
          end
        end

        # Sauvegarde dans le modèle SketchUp
        data.each { |key, value| dict[key] = value }
        
        # Mise à jour des autres plugins
        update_thermal_params(data)
        
        UI.messagebox("Paramètres enregistrés avec succès!\nTempérature extérieure: #{data["temp_ext"]}°C")
        true
      rescue JSON::ParserError => e
        UI.messagebox("Erreur de format des données: #{e.message}")
        false
      rescue => e
        UI.messagebox("Erreur lors de la sauvegarde: #{e.message}")
        false
      end
    end

    # Callback pour charger les paramètres existants
    @dialog.add_action_callback("charger_params") do |_dlg, _params|
      begin
        json_data = {}
        
        # Chargement depuis le modèle SketchUp avec valeurs par défaut
        dict.each_pair do |k, v|
          json_data[k] = v
        end

        # Valeurs par défaut si manquantes
        json_data["temp_ext"] ||= TEMP_EXT_DEFAULT
        json_data["coef_securite"] ||= COEF_SECURITE_DEFAULT
        
        @dialog.execute_script("charger_params(#{json_data.to_json})")
      rescue => e
        UI.messagebox("Erreur lors du chargement: #{e.message}")
      end
    end

    @dialog.show
  end

  # Met à jour les paramètres thermiques dans les autres plugins
  def self.update_thermal_params(data)
    model = Sketchup.active_model
    pc_dict = model.attribute_dictionary("PC_Params", true)
    
    if data.key?("temp_ext")
      pc_dict["outdoorTemp"] = data["temp_ext"].to_f
    end
    
    if data.key?("coef_securite")
      pc_dict["safety_coef"] = data["coef_securite"].to_f / 100.0
    end
  end

  # Méthode pour récupérer un paramètre spécifique
  def self.parametre(key)
    dict = Sketchup.active_model.attribute_dictionary(DICTIONARY, false)
    return nil unless dict
    
    case key.to_s
    when "temp_ext"
      dict[key] || TEMP_EXT_DEFAULT
    when "coef_securite"
      dict[key] || COEF_SECURITE_DEFAULT
    else
      dict[key]
    end
  end

  unless file_loaded?(__FILE__)
    # Ajout au menu Extensions seulement
    UI.menu("Extensions").add_item(PLUGIN_NAME) { self.afficher_dialogue }
    
    file_loaded(__FILE__)
  end
end