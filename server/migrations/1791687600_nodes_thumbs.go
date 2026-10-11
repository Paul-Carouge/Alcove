package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

// Thumbnail sizes PocketBase may generate (lazily, cached next to the file,
// originals untouched) for images in nodes.blob:
//   - 96x96   list icons (center crop)
//   - 320x320 grid tiles (center crop)
//   - 1600x0  viewer (fit width, keep ratio)
var nodeThumbs = []string{"96x96", "320x320", "1600x0"}

func init() {
	m.Register(func(app core.App) error {
		return setNodeThumbs(app, nodeThumbs)
	}, func(app core.App) error {
		return setNodeThumbs(app, nil)
	})
}

func setNodeThumbs(app core.App, thumbs []string) error {
	nodes, err := app.FindCollectionByNameOrId("nodes")
	if err != nil {
		return err
	}
	nodes.Fields.GetByName("blob").(*core.FileField).Thumbs = thumbs
	return app.Save(nodes)
}
