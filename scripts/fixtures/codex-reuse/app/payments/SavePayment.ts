import {parseAmount} from "../../packages/domain/parseAmount";
export function preparePayment(input:string) { return {amountCents:parseAmount(input)}; }
