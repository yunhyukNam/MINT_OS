[ORG 0x00]          ; 코드의 시작 어드레스를 0x00으로 설정
[BITS 16]           ; 이하의 코드는 16비트 코드로 설정

SECTION .text           ; text 섹션(세그먼트)을 정의

jmp 0x07C0:START        ; cs 레지스터에 0x07C0을 복사하면서 START Label로 이동

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   MINT64 OS에 관련된 환경 설정 값
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TOTALSECTORCOUNT:   dw  1024        ; 부트 로더를 제외한 MINT64 OS 이미지의 크기
                                    ; 최대 1152 섹터(0x90000byte)까지 가능

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START:
    mov ax, 0x07C0      ; ax 레지스터에 BootLoader의 시작 Addr(0x07C0) 복사
    mov ds, ax          ; ds 레지스터에 ax의 값 복사
    mov ax, 0xB800      ; ax 레지스터에 비디오 메모리의 시작 Addr(0xB800) 복사
    mov es, ax          ; es 레지스터에 ax의 값 복사


    ; 스택을 0x0000:0000~0x0000:FFFF 영역에 64kB 크기로 생성
    mov ax, 0x0000      ; ax 레지스터에 ss의 시작 Addr(0x0000)를 복사
    mov ss, ax          ; ss 레지스터에 ax의 값 복사
    mov sp, 0xFFFE      ; sp 레지스터의 Addr을 0xFFFE로 설정
    mov bp, 0xFFFE      ; bp 레지스터의 Addr을 0xFFFE로 설정

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 화면을 모두 지우고, 속성값을 녹색으로 설정
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov si, 0           ; si 레지스터(문자열 원본 인덱스 레지스터)를 초기화

.SCREENLOOP:                        ; 화면 지우는 Loop
    mov byte [ es:si ], 0           ; 비디오 메모리의 문자가 위치하는 Addr에
                                    ; 0을 복사하여 문자를 삭제
    mov byte [ es:si + 1 ], 0x0A    ; 비디오 메모리의 속성이 위치하는 Addr에
                                    ; 0x0a(검은 바탕에 밝은 녹색)을 복사

    add si, 2                       ; 문자와 속성을 설정한 뒤 다음 위치로 이동(Addr+2)

    cmp si, 80 * 25 * 2     ; 화면의 전체 크기는 80X25
                            ; 출력한 문자 수를 비교하는 si 레지스터와 비교
    jl .SCREENLOOP          ; si 레지스터가 80 * 25 * 2보다 작다면 아직 지우지 못한
                            ; 영역이 있으므로 .SCREENLOOP(화면 지우기)로 이동

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 화면 상단에 시작 메세지 출력
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    push MESSAGE1               ; 출력할 메세지의 Addr을 스택에 push
    push 0                      ; 화면의 Y 좌표를 스택에 push
    push 0                      ; 화면의 X 좌표를 스택에 push
    call PRINTMESSAGE           ; PRINTMESSAGE 함수 호출
    add  sp, 6                  ; 삽입한 파라미터(x좌표, y좌표, MESSAGE1's Addr) 제거

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; OS 이미지를 로딩한다는 메세지 출력
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    push IMAGELOADINGMESSAGE    ; 출력할 메세지의 Addr를 스택에 push
    push 1                      ; 화면의 Y 좌표를 스택에 push
    push 0                      ; 화면의 X 좌표를 스택에 push
    call PRINTMESSAGE           ; PRINTMESSAGE 함수 호출
    add  sp, 6                  ; 삽입한 파라미터(x좌표, y좌표, MESSAGE1's Addr) 제거

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 디스크에서 OS 이미지를 로딩
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 디스크를 읽기 전에 먼저 리셋
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RESETDISK:                          ; 디스크를 리셋하는 코드의 시작
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; BIOS Reset Function 호출
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 서비스 번호 0, 드라이브 번호(0=Floppy)
    mov ax, 0
    mov dl, 0
    int 0x13
    ; 에러가 발생하면 에러 처리로 이동
    jc  HANDLEDISKERROR

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 디스크에서 섹터를 읽음
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 디스크의 내용을 메모리로 복사할 어드레스(ES:BX)를 0x1000으로 설정
    mov si, 0x1000          ; OS 이미지를 복사 할 Addr0x1000()를 si에 복사
    mov es, si              ; es 레지스터에 si에 저장된 Addr 복사
    mov bx, 0x0000          ; bx 레지스터에 0x0000을 설정하여 복사

    mov di, word [ TOTALSECTORCOUNT ]   ; 복사할 OS 이미지의 섹터 수를 di 레지스터에 저장

READDATA:                       ; 디스크를 읽는 코드 시작
    ; 모든 섹터를 읽었는지 확인
    cmp di, 0               ; 복사할 OS 이미지의 섹터 수를 0과 비교
    je READEND              ; 복사할 섹터 수가 0이라면 다 복사 했으므로 READEND로 이동
    sub di, 0x1             ; 복사할 섹터 수를 1 감소

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; BIOS Read Function 호출
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov ah, 0x02                    ; BIOS 서비스 번호 2(Read Sector)
    mov al, 0x1                     ; 읽을 섹터 수는 1
    mov ch, byte [ TRACKNUMBER ]    ; 읽을 트랙 번호 설정
    mov cl, byte [ SECTORNUMBER ]   ; 읽을 섹터 번호 설정
    mov dh, byte [ HEADNUMBER ]     ; 읽을 헤더 번호 설정
    mov dl, 0x00                    ; 읽을 드라이브 번호(0=Floppy) 설정
    int 0x13                        ; interrept 서비스 수행
    jc HANDLEDISKERROR              ; 에러가 발생했다면 HANDLEDISKERROR로 이동

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 복사할 Addr과 트랙, 헤드, 섹터 Addr 계산
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    add si, 0x0020      ; 512(0x200) 바이트만큼 읽었으므로, 이를 세그먼트 레지스터 값으로 변환
    mov es, si

    ; 한 섹터를 읽었으므로 섹터 번호를 1 증가시키고 마지막 섹터(18)까지 읽었는지 판단
    ; 마지막 섹터가 아니면 섹터 읽기로 이동해서 다시 섹터 읽기 수행
    mov al, byte [ SECTORNUMBER ]       ; 섹터 번호를 al 레지스터에 설정
    add al, 0x01                        ; 섹터 번호 1 증가
    mov byte [ SECTORNUMBER ], al       ; 1 증가된 섹터 번호를 재설정
    cmp al, 37                          ; 증가시킨 섹터 번호를 37과 비교

    jl READDATA                         ; 섹터 번호가 19 미만이면 READDATA로 JMP

    ; 마지막 섹터까지 읽었으면(SECTORNUMBER가 19라면) 헤드를 토글(0->1, 1->0)하고,
    ; 섹터 번호를 1로 설정
    xor byte [ HEADNUMBER ], 0x01       ; 헤드 번호를 0x01과 xor 하여 토글(0->1, 1->0)
    mov byte [ SECTORNUMBER ], 0x01     ; 섹터 번호를 다시 1로 설정

    ; if 헤드가 1->0으로 바뀌었다면 양쪽 HEAD를 모두 읽은 것이므로 아래로 이동하여
    ; 트랙 번호를 1 증가
    cmp byte [ HEADNUMBER ], 0x00       ; 헤드 번호를 0x00과 비교
    jne READDATA                        ; 헤드 번호가 0이 아니면 READDATA로 이동

    ; 트랙을 1 증가시킨 후 다시 섹터 읽기로 이동
    add byte [ TRACKNUMBER ], 0x01      ; 트랙 번호를 1 증가
    jmp READDATA                        ; READDATA로 이동

READEND:
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; OS 이미지 읽기가 완료되었다는 메세지를 출력
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    push LOADINGCOMPLETEMESSAGE     ; 출력할 메세지의 Addr을 push
    push 1                          ; 화면의 Y 좌표를 push
    push 20                         ; 화면의 X 좌표를 push
    call PRINTMESSAGE               ; PRINTMESSAGE 함수 호출
    add sp, 6                       ; 파라미터 제거

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; 로딩한 가상 OS 이미지 실행
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp 0x1000:0x0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 함수 코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 디스크 에러를 처리하는 함수
HANDLEDISKERROR:
    push DISKERRORMESSAGE   ; 에러 문자열의 Addr을 push
    push 1                  ; 화면의 Y 좌표를 push
    push 20                 ; 화면의 X 좌표를 push
    call PRINTMESSAGE       ; PRINTMESSAGE 함수 호출

    jmp $                   ; 현재 위치에서 무한 루프

; 메세지를 출력하는 함수
; PARAM: x, y, 문자열
PRINTMESSAGE:
    push bp             ; function prologue
    mov bp, sp

    push es             ; es ~ dx 까지 push
    push si
    push di
    push ax
    push cx
    push dx

    ; es에 비디오 모드 Addr 설정

    mov ax, 0xB800     ; 비디오 메모리 시작 Addr(0xB800)을
                       ; ax에 복사한 후 es 레지스터에 설정
    mov es, ax

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; X, Y의 좌표로 비디오 메모리의 어드레스를 계산함
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; Y 좌표를 이용해서 먼저 라인 어드레스를 구함
    mov ax, word [ bp + 6 ]     ; 파라미터 2(화면 좌표 Y)를 ax 레지스터에 설정
    mov si, 160                 ; 한 라인의 바이트 수(2 * 80 컬럼)를 si 레지스터에 설정
    mul si                      ; ax 레지스터와 si 레지스터를 곱하여 화면 Y 어드레스 계산
    mov di, ax                  ; 계산된 화면 Y 어드레스를 di 레지스터에 설정
    
    ; X 좌표를 이용해서 2를 곱한 후 최종 어드레스를 구함
    mov ax, word [ bp + 4 ]     ; 파라미터 1(화면 좌표 X)를 ax 레지스터에 설정
    mov si, 2                   ; 한 문자를 나타내는 바이트 수(2)를 si 레지스터에 설정
    mul si                      ; ax 레지스터와 si 레지스터를 곱하여 화면 X 어드레스를 계산
    add di, ax                  ; 화면 Y 어드레스와 계산된 X 어드레스를 더해서
                                ; 실제 비디오 메모리 어드레스를 계산
    
    ; 출력할 문자열의 어드레스      
    mov si, word [ bp + 8 ]     ; 파라미터 3(출력할 문자열의 어드레스)

.MESSAGELOOP:
    mov cl, byte [ si ]  ; MESSAGE1의 Addr에서 si 레지스터 값만큼
                                    ; 더한 위치의 문자를 cl 레지스터에 복사
                                    ; cl 레지스터는 cx 레지스터의 하위 1byte를 의미
                                    ; 문자열은 1byte면 충분하므로 cx 레지스터의 하위 1byte만 사용
    cmp cl, 0           ; 복사된 문자와 0을 비교
    je .MESSAGEEND      ; 복사한 문자의 값이 0이면 문자열이 종료되었음을
                        ; 의미하므로 .MESSAGEEND로 이동하여 문자 출력 종료
    
    mov byte [ es:di ], cl  ; 0이 아니라면 비디오 메모리 Addr 0xb800:di에 문자를 출력

    add si, 1           ; si 레지스터에 1을 더하여 다음 문자열로 이동
    add di, 2           ; di 레지스터에 2를 더하여 비디오 메모리의 다음 문자 위치로 이동
                        ; 비디오 메모리는 (문자, 속성)의 쌍으로 구성되므로 문자만 출력하려면
                        ; 2를 더해야 함

    jmp .MESSAGELOOP    ; 메세지 출력 루프로 이동하여 다음 문자를 출력

.MESSAGEEND:
    pop dx      ; 사용이 끝난 dx ~ es 레지스터를 스택에
    pop cx      ; 삽입된 값을 이용해 복원
    pop ax      ; Stack 구조는 가장 마지막에 들어간 데이터가 가장 먼저 나오게 되는
    pop di      ; 자료구조(LI-FO)이므로 push의 역순으로
    pop si      ; pop 해야 함
    pop es      
    pop bp      ; basepointer 복원

    ret         ; 함수 호출 후 다음 코드의 위치로 복귀

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   데이터 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 부트 로더 시작 메시지
MESSAGE1:   db 'MINT64 OS Boot Loader Start!', 0    ; 출력할 메세지 정의
                                                    ; 마지막 문자는 0으로 설정하여 .MESSAGELOOP에서
                                                    ; 문자열이 종료되었음을 알 수 있도록 함
DISKERRORMESSAGE:   db  'DISK Error! Try again', 0
IMAGELOADINGMESSAGE:    db  'OS Image Loading...', 0
LOADINGCOMPLETEMESSAGE: db  'Complete!!', 0

; 디스크 read 관련 변수
SECTORNUMBER:   db  0x02    ; OS 이미지가 시작하는 Sector num을 저장
HEADNUMBER:     db  0x00    ; OS 이미지가 시작하는 Head num을 저장
TRACKNUMBER:    db  0x00    ; OS 이미지가 시작하는 Track num을 저장

times 510 - ( $ - $$ )      db      0x00    ; $: 현재 라인의 어드레스
                                            ; $$: 현재 섹션(.text)의 시작 어드레스
                                            ; $ - $$: 현재 섹션을 기준으로 하는 오프셋
                                            ; 510 - ( $ - $$ ): 현재부터 어드레스 510까지
                                            ; db 0x00: 1바이트를 선언하고 값은 0x00
                                            ; time: 반복 수행
                                            ; 현재 위치에서 어드레스 510까지 0x00으로 채움

db 0x55             ; 1바이트를 선언하고 값은 0x55
db 0xAA             ; 1바이트를 선언하고 값은 0xAA
                    ; 어드레스 511, 512에 0x55, 0xAA를 써서 부트 섹터로 표기함