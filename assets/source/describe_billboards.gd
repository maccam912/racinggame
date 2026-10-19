extends SceneTree
## Preserve generated PNG bytes; author UV bounds from the same alpha-scissor rule.
func _initialize() -> void:
	var source := "res://assets/source/billboards/generation.json"
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var rows: Array[Dictionary] = []
	assert(DirAccess.make_dir_recursive_absolute("res://assets/exported/billboards")==OK)
	for row: Dictionary in provenance.assets:
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://"+str(row.source)))
		assert(image!=null)
		image.convert(Image.FORMAT_RGBA8)
		var pixels := image.get_data()
		var minimum := image.get_size()
		var maximum := Vector2i(-1,-1)
		var clear := 0
		var solid := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var alpha := pixels[(y*image.get_width()+x)*4+3]
				if alpha==0: clear += 1
				if alpha<128: continue
				solid += 1
				minimum = minimum.min(Vector2i(x,y))
				maximum = maximum.max(Vector2i(x,y))
		assert(solid>10000 and clear>image.get_width()*image.get_height()/4)
		var bounds := Rect2i(minimum,maximum-minimum+Vector2i.ONE)
		var target := "res://assets/exported/billboards/"+str(row.id)+"-v1.png"
		var bytes := FileAccess.get_file_as_bytes("res://"+str(row.source))
		var file := FileAccess.open(target,FileAccess.WRITE)
		assert(file!=null)
		file.store_buffer(bytes)
		file.close()
		assert(FileAccess.get_sha256(target)==row.sha256)
		rows.append({"id":row.id,"path":target.trim_prefix("res://"),"source":row.source,"sha256":row.sha256,"pixels":[image.get_width(),image.get_height()],"alpha_scissor":.5,"uv_bounds_pixels":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"solid_pixels":solid,"transparent_pixels":clear})
	var catalog := {"schema_version":1,"source":source.trim_prefix("res://"),"license":"MIT","creator":"OpenAI image generation directed by the Pacific Rush project","assets":rows}
	var output := FileAccess.open("res://assets/exported/billboards/catalog.json",FileAccess.WRITE)
	assert(output!=null)
	output.store_string(JSON.stringify(catalog,"\t")+"\n")
	output.close()
	print("ORIGINAL_BILLBOARD_ALPHA_BOUNDS_CATALOG_PASS ",JSON.stringify(rows))
	quit()
