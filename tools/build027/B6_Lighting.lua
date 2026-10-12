-- Studio location: ServerStorage.Build027.B6_Lighting (ModuleScript)
-- Bright sky, warm late-afternoon light ("dusk-style" warmth without darkness). The previous values
-- are in ServerStorage._Backups.Pre027_Phase2_2026-10-12.Lighting (attributes + effect copies).
-- 030 tune per docs/ART_STYLE.md (less washed out: lower brightness, more contrast/saturation, light haze
-- for depth, bloom only on gold/neon). The 027 values are in ServerStorage._Backups.Pre030_Lighting.

local Lighting = game:GetService("Lighting")

return function(): string
	Lighting.ClockTime = 15.2 -- warm afternoon, sun high enough to stay out of the Main Street view
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(108, 100, 94)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 142, 134)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 226, 190)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ExposureCompensation = 0
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true
	local function effect(class: string): any
		local e = Lighting:FindFirstChildOfClass(class)
		if not e then
			e = Instance.new(class)
			e.Parent = Lighting
		end
		return e
	end
	local atmosphere = effect("Atmosphere")
	atmosphere.Density = 0.27
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(226, 236, 255)
	atmosphere.Decay = Color3.fromRGB(255, 214, 170)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 0.8
	local bloom = effect("BloomEffect")
	bloom.Enabled, bloom.Intensity, bloom.Size, bloom.Threshold = true, 0.5, 20, 1.9
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Enabled, rays.Intensity, rays.Spread = true, 0.04, 0.6
	end
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false -- blurs the Vault at the end of the lane
	end
	local cc = Lighting:FindFirstChild("SAB_ColorCorrection") or effect("ColorCorrectionEffect")
	cc.Brightness, cc.Contrast, cc.Saturation = -0.03, 0.14, 0.26
	cc.TintColor = Color3.fromRGB(255, 250, 244)
	return "lighting set"
end
