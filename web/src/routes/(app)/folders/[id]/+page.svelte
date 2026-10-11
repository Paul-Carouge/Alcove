<script lang="ts">
	import { page } from '$app/state';
	import DriveView from '#lib/drive/DriveView.svelte';
</script>

{#key page.params.id}
	<DriveView folderId={page.params.id ?? ''} />
{/key}
