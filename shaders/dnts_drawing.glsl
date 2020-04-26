#version 120

uniform sampler2D mapTex;

uniform int colorIndex;

vec4 texture1 = vec4(1.0, 0.0, 1.0, 0.0);
vec4 texture2 = vec4(0.0, 1.0, 0.0, 1.0);
vec4 eraser = vec4(0.0, 0.0, 0.0, 0.0);

void main(void) {
  if (colorIndex == 0) {
    gl_FragColor = texture1;
  } else if (colorIndex == 1) {
    gl_FragColor = texture2;
  } else {
    gl_FragColor = eraser;
  }
}
