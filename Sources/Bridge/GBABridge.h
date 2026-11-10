#ifndef GBABRIDGE_H
#define GBABRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Carrega a ROM e inicia o nucleo. Devolve 0 se deu certo. */
int gba_load(const char *path);
void gba_unload(void);

/* Executa um quadro de emulacao. */
void gba_run_frame(void);

/* Botoes: bit N = RETRO_DEVICE_ID_JOYPAD_* de numero N (B=0, SELECT=2, START=3,
 * UP=4, DOWN=5, LEFT=6, RIGHT=7, A=8, L=10, R=11). */
void gba_set_keys(uint32_t mask);

/* Ultimo quadro em BGRA8888 (largura*altura pixels, sem espaco entre linhas). */
const uint32_t *gba_frame(int *width, int *height);

/* Audio estereo: copia ate "frames" amostras para left/right (float) e devolve quantas
 * eram reais; o resto e preenchido com silencio. Pode ser chamado na thread de audio. */
int gba_audio_pull(float *left, float *right, int frames);
int gba_audio_buffered(void);

/* Modo acelerado: sem audio. */
void gba_set_turbo(int on);

/* Memoria de save (SRAM/Flash) do jogo carregado. */
void *gba_save_data(void);
size_t gba_save_size(void);

double gba_fps(void);

#ifdef __cplusplus
}
#endif

#endif
