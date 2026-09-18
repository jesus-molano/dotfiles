// Parses user decimal input; rejects malformed or negative values. Output is integer cents.
export function parseAmount(input:string):number { const n=Number(input.replace(",", ".")); if(!Number.isFinite(n)||n<0) throw new Error("Invalid amount"); return Math.round(n*100); }
