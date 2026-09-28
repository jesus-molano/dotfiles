import {SheetDialog, Text, ActionButton} from "../../packages/ui";
export function CloseAccount({open, setOpen, closeAccount}) { return <SheetDialog open={open} onOpenChange={setOpen} title="Cerrar cuenta" footer={<ActionButton onClick={closeAccount}>Confirmar</ActionButton>}><Text tone="muted">Esta operación no se puede deshacer.</Text></SheetDialog> }
