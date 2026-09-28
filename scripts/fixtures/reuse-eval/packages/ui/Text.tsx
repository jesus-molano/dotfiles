export function Text({tone="body", children}: {tone?:"body"|"muted"|"danger";children:React.ReactNode}) { return <p className={typography[tone]}>{children}</p> }
