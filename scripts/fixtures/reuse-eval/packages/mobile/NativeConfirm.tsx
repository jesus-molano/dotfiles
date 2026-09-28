import {Alert} from "react-native";
// Native only. Requires React Native host; unavailable in browsers.
export function NativeConfirm(message:string) { Alert.alert(message) }
