export function renderScaffold() {
  return `
    <main class="tracking-shell" aria-labelledby="page-title">
      <section class="intro-card">
        <div class="intro-copy">
          <h1 id="page-title">HaulMate broker tracking</h1>
          <p>
            Static TypeScript scaffold for the public, per-load tracking page.
            The live tracking contract arrives in KAN-41.
          </p>
        </div>

        <dl class="guardrails" aria-label="Tracking page guardrails">
          <div>
            <dt>No broker login.</dt>
            <dd>Access will be controlled by a revocable share token.</dd>
          </div>
          <div>
            <dt>Approved public fields only.</dt>
            <dd>Status, stops, ETA, delay, freshness, and POD availability.</dd>
          </div>
          <div>
            <dt>Private freight data stays private.</dt>
            <dd>No rates, profit, expenses, precise coordinates, or private documents.</dd>
          </div>
        </dl>
      </section>
    </main>
  `
}
