module PlancherChauffant
  # Calcul des surfaces
  def self.calculate_area(entity)
    return 0.0 unless entity.valid?
    entity.bounds.area * 0.0254 * 0.0254 # Conversion pieds² → m²
  rescue
    0.0
  end

  # Gestion des matériaux
  module Materials
    LIST = {
      pex: { color: [0, 100, 255], diameter: 0.016 },
      multilayer: { color: [255, 100, 0], diameter: 0.016 }
    }.freeze

    def self.list
      LIST
    end
  end

  # Tracé des boucles
  module LoopDrawer
    def self.draw(group, spacing_cm, max_length_m)
      model = Sketchup.active_model
      model.start_operation("Tracé des boucles", true)
      
      bounds = group.bounds
      spacing_m = spacing_cm / 100.0
      z_offset = 0.3 # 30cm au dessus du sol

      # Création du groupe pour les boucles
      entities = model.active_entities
      loop_group = entities.add_group
      loop_group.name = "Boucles PC - Pas #{spacing_cm}cm"

      # Matériau
      material = model.materials.add("Tuyau PC")
      material.color = Materials::LIST[:pex][:color]

      # Calcul du nombre de lignes
      nb_lines = (bounds.depth / spacing_m).ceil

      # Tracé
      (0..nb_lines).each do |i|
        draw_pipe(
          loop_group.entities,
          bounds.corner(0) + [0, i * spacing_m, z_offset],
          bounds.corner(2) + [0, i * spacing_m, z_offset],
          Materials::LIST[:pex][:diameter],
          material
        )
      end

      model.commit_operation
      true
    rescue => e
      model.abort_operation
      UI.messagebox("Erreur: #{e.message}")
      false
    end

    private

    def self.draw_pipe(entities, pt1, pt2, diameter, material)
      direction = pt2 - pt1
      length = direction.length
      direction.normalize!

      circle = entities.add_circle(pt1, direction, diameter / 2, 16)
      face = entities.add_face(circle)
      face.pushpull(-length)
      face.material = material
    end
  end

  # Enregistrement des commandes
  unless file_loaded?(__FILE__)
    UI.menu("Extensions").add_item("Dimensionner Plancher") do
      ParametresThermiques.show_dialog
    end
    
    file_loaded(__FILE__)
  end
end