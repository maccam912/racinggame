# Native visual regression — distant cliffs outside the ground extent

The content-9 draft native u=.85 Caldera view shows the distant formations beyond the exported ground bounds, with broad bases above the floor. Geometry bounds/collision tests alone did not detect this visual problem. The correction extends only the two new terrains, embeds cliff/spire bases and adds a check that their complete mesh footprints have underlying terrain. The previous eight route/terrain bytes stay exact. This image and its source remain the failed visual reference.
