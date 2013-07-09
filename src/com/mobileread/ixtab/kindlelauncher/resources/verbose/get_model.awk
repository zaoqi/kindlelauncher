function get_model(file, line, device) {
	if (MODEL) return MODEL
	MODEL = "Unknown"
	# Devise the model from the device code, which we get from the S/N. See KindleTool's kindle_tool.h for the list of device codes.
	file = "/proc/usid"
	while ((getline line < file) > 0) {
		# Strips the B0 (leading 2 chars), that should help with those weird K4 starting in 90 instead of B0...
		device = substr(line, 3, 2)
		if (device ~ /^(02)|(03)$/) {
			MODEL = "Kindle2"
			break
		}
		else if (device ~ /^(04)|(05)$/) {
			MODEL = "KindleDX"
			break
		}
		else if (device ~ /^(09)$/) {
			MODEL = "KindleDXG"
			break
		}
		else if (device ~ /^(08)|(06)|(0A)$/) {
			MODEL = "Kindle3"
			break
		}
		else if (device ~ /^(0E)|(23)$/) {
			MODEL = "Kindle4"
			break
		}
		else if (device ~ /^(0F)|(11)|(10)|(12)$/) {
			MODEL = "KindleTouch"
			break
		}
		else if (device ~ /^(24)|(1B)|(1D)|(1F)|(1C)|(20)$/) {
			MODEL = "KindlePaperWhite"
			break
		}
	}
	close(file)

	return MODEL
}

BEGIN { print get_model() }
