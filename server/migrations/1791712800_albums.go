package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

const mediaOwnerRule = "owner = @request.auth.id"

// mediaViewRule lets the people of an album read the photos it contains (ADR 0018).
const mediaViewRule = mediaOwnerRule +
	" || album_items_via_media.album.owner ?= @request.auth.id" +
	" || album_items_via_media.album.members.id ?= @request.auth.id" +
	" || album_items_via_media.album.contributors.id ?= @request.auth.id"

// Albums, shared with other accounts as viewers (members) or contributors (ADR 0018).
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		media, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			return err
		}

		albums := core.NewBaseCollection("albums")
		albums.Fields.Add(
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "name", Required: true, Min: 1, Max: 100},
			&core.RelationField{Name: "cover", CollectionId: media.Id, MaxSelect: 1},
			&core.RelationField{Name: "members", CollectionId: users.Id, MaxSelect: 100, Help: "Can view"},
			&core.RelationField{Name: "contributors", CollectionId: users.Id, MaxSelect: 100, Help: "Can view and add their photos"},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		participant := "(owner = @request.auth.id || members.id ?= @request.auth.id || contributors.id ?= @request.auth.id)"
		albums.ListRule = types.Pointer(`@request.auth.collectionName = "users" && ` + participant)
		albums.ViewRule = albums.ListRule
		albums.CreateRule = types.Pointer(`@request.auth.collectionName = "users" && @request.body.owner = @request.auth.id`)
		albums.UpdateRule = types.Pointer(`owner = @request.auth.id && @request.body.owner:isset = false`)
		albums.DeleteRule = types.Pointer("owner = @request.auth.id")
		albums.AddIndex("idx_albums_owner", false, "owner", "")
		if err := app.Save(albums); err != nil {
			return err
		}

		items := core.NewBaseCollection("album_items")
		items.Fields.Add(
			&core.RelationField{Name: "album", CollectionId: albums.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.RelationField{Name: "media", CollectionId: media.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.RelationField{Name: "added_by", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.AutodateField{Name: "created", OnCreate: true},
		)
		inAlbum := "(album.owner = @request.auth.id || album.members.id ?= @request.auth.id || album.contributors.id ?= @request.auth.id)"
		items.ListRule = types.Pointer(`@request.auth.collectionName = "users" && ` + inAlbum)
		items.ViewRule = items.ListRule
		// Only your own photos, into albums you own or contribute to.
		items.CreateRule = types.Pointer(`@request.auth.collectionName = "users" && added_by = @request.auth.id && ` +
			`media.owner = @request.auth.id && (album.owner = @request.auth.id || album.contributors.id ?= @request.auth.id)`)
		items.DeleteRule = types.Pointer("album.owner = @request.auth.id || added_by = @request.auth.id")
		items.AddIndex("idx_album_items_unique", true, "album, media", "")
		items.AddIndex("idx_album_items_media", false, "media", "")
		if err := app.Save(items); err != nil {
			return err
		}

		media.ViewRule = types.Pointer(mediaViewRule)
		return app.Save(media)
	}, func(app core.App) error {
		media, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			return err
		}
		media.ViewRule = types.Pointer(mediaOwnerRule)
		if err := app.Save(media); err != nil {
			return err
		}
		for _, name := range []string{"album_items", "albums"} {
			c, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				return err
			}
			if err := app.Delete(c); err != nil {
				return err
			}
		}
		return nil
	})
}
