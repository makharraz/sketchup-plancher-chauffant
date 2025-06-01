require 'sketchup.rb'
require 'json'

module ParametresThermiques
  class Dialog
    def initialize
      @dialog = UI::HtmlDialog.new(
        dialog_title: "Dimensionnement Plancher Chauffant",
        preferences_key: "PlancherChauffantParams",
        width: 1000,
        height: 700,
        resizable: true,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      setup_callbacks
    end

    def show
      html_path = File.join(File.dirname(__FILE__), "interface.html")
      if File.exist?(html_path)
        @dialog.set_file(html_path)
        @dialog.show
      else
        UI.messagebox("Erreur : Fichier interface.html introuvable dans #{html_path}")
      end
    end

    private

    def setup_callbacks
      # Chargement initial des données
      @dialog.add_action_callback("ready") do |_|
        load_initial_data
      end

      # Sauvegarde des paramètres
      @dialog.add_action_callback("save_settings") do |_, json|
        save_settings(json)
      end

      # Tracé des boucles
      @dialog.add_action_callback("draw_loops") do |_, params|
        draw_heating_loops(params)
      end

      # Récupération des paramètres projet
      @dialog.add_action_callback("get_project_params") do |_, _|
        get_project_params
      end
    end

    def load_initial_data
      model = Sketchup.active_model
      selection = model.selection
      pc_dict = model.attribute_dictionary("PC_Params", {})
      project_dict = model.attribute_dictionary("ParametresProjet", {})

      # Données par défaut
      data = {
        outdoorTemp: project_dict["temp_ext"] || -5.0,
        safetyCoef: (project_dict["coef_securite"] || 15.0).to_f / 100.0,
        room: {
          name: selection.empty? ? "Pièce" : selection.first.name,
          area: PlancherChauffant.calculate_area(selection.first)
        },
        materials: PlancherChauffant::Materials.list,
        hydraulic: {
          flowTemp: pc_dict["flowTemp"] || 45.0,
          returnTemp: pc_dict["returnTemp"] || 35.0
        }
      }

      # Chargement des paramètres sauvegardés
      pc_dict.each { |k, v| data[k.to_sym] = v unless data.key?(k.to_sym) }

      @dialog.execute_script("init(#{data.to_json})")
    rescue => e
      UI.messagebox("Erreur lors du chargement : #{e.message}\n#{e.backtrace.join("\n")}")
    end

    def save_settings(json)
      model = Sketchup.active_model
      begin
        data = JSON.parse(json)
        dict = model.attribute_dictionary("PC_Params", true)
        
        # Filtrage et conversion des données
        settings = {
          "wallU" => data["thermal"]["walls"]["u"].to_f,
          "windowU" => data["thermal"]["windows"]["u"].to_f,
          "flowTemp" => data["hydraulic"]["flowTemp"].to_f,
          "returnTemp" => data["hydraulic"]["returnTemp"].to_f,
          "pipeType" => data["hydraulic"]["pipeType"].to_s
        }
        
        # Sauvegarde
        settings.each { |k, v| dict[k] = v }
        true
      rescue JSON::ParserError => e
        UI.messagebox("Erreur de format JSON : #{e.message}")
        false
      rescue => e
        UI.messagebox("Erreur de sauvegarde : #{e.message}")
        false
      end
    end

    def draw_heating_loops(params)
      model = Sketchup.active_model
      model.start_operation("Tracer les boucles", true)
      
      begin
        selection = model.selection
        return false if selection.empty?
        
        spacing = params["spacing"].to_f
        max_length = params["max_length"].to_f
        pipe_type = params["pipeType"].to_sym

        success = PlancherChauffant::LoopDrawer.draw(
          selection.first,
          spacing,
          max_length,
          pipe_type
        )

        model.commit_operation
        success
      rescue => e
        model.abort_operation
        UI.messagebox("Erreur lors du tracé : #{e.message}")
        false
      end
    end

    def get_project_params
      model = Sketchup.active_model
      dict = model.attribute_dictionary("ParametresProjet", {})
      
      {
        temp_ext: dict["temp_ext"] || -5.0,
        coef_securite: dict["coef_securite"] || 15.0
      }.to_json
    rescue => e
      { error: e.message }.to_json
    end
  end

  # Interface publique
  def self.show_dialog
    Dialog.new.show
  end
end