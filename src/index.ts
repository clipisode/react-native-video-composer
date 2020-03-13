import { NativeModules } from "react-native";

const { VideoComposer } = NativeModules;

export function compose(one: string, two: string): Promise<string> {
  return VideoComposer.compose(one, two);
}
