export function ActionButton({onClick, children}: {onClick:()=>void;children:React.ReactNode}) { return <button className={tokens.action} onClick={onClick}>{children}</button> }
