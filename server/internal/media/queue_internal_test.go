package media

import "testing"

// A sweep must not queue an item twice, and one dropped by a full queue must be queueable again.
func TestEnqueueDedupesAndForgetsDropped(t *testing.T) {
	w := &worker{queue: make(chan string, 2), done: make(chan struct{})}
	w.enqueue("a")
	w.enqueue("a")
	w.enqueue("b")
	w.enqueue("c") // full: dropped
	if len(w.queue) != 2 {
		t.Fatalf("queue holds %d, want 2", len(w.queue))
	}
	if _, ok := w.queued.Load("c"); ok {
		t.Fatal("a dropped id stays marked as queued")
	}
	<-w.queue
	w.queued.Delete("a")
	w.enqueue("c")
	if len(w.queue) != 2 {
		t.Fatalf("dropped id not requeued: %d", len(w.queue))
	}
}
