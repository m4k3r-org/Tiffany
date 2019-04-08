#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "vm.h"

// Test vectors for the VM, generated by stepping the VM one group at a time,
// starting at address 0.
// Command in Tiff is "N make ../templates/testbench.c ../testbench/test.c".
// Note that the registers/stacks will be hosed after test vector generation.

// Test vectors are embedded in a function
// Register IDs: 0 to 5 = T, N, RP, SP, UP, PC

int errors = 0;
int TestID;

// C testbench:

uint32_t ChangeRegs[2][6];              // rows: old, new
int changed;                            // list of registers to check
int tests = 0;

void RegChangeInit (void) {             // Initialize register changes
    for (int i=0; i<6; i++) {
        uint32_t x = vmRegRead(i);
        ChangeRegs[0][i] = x;
        ChangeRegs[1][i] = x;
    }
    ChangeRegs[1][5] -= 4;
    changed = 0;
}

void RegChanges (void) {				// process registor changes
    memmove(ChangeRegs[1], ChangeRegs[0], 6*sizeof(uint32_t));
    for (int i=0; i<6; i++) {           // [1] = expected, [0] = actual
        ChangeRegs[0][i] = vmRegRead(i);
    }
    int changed = 0;
    for (int i=0; i<6; i++) {           // compare...
        uint32_t actual   = ChangeRegs[0][i];
        uint32_t expected = ChangeRegs[1][i];
        if (actual != expected) {
            changed |= (1<<i);          // tag the registers changed
        }
    }
}

void newstep(uint32_t IR, int testID){
    if (changed) {
        printf("Unexpected changes detected in test %d: ", TestID);
        for (int i=0; i<6; i++) {
            if ((1<<i) & changed) {
                printf("%d ", i);
            }
        }
        printf("\n");
    }
    VMstep(IR, 0);
    RegChanges();
    TestID = testID;
    tests++;
};

void changes(int Reg, uint32_t actual){
	static uint32_t previous = 0;
    if (actual != ChangeRegs[0][Reg]) {
        errors++;
        printf("[%d]: New R%d: expected 0x%08X, is 0x%08X, old was 0x%08X\n",
               TestID, Reg, actual, ChangeRegs[0][Reg], previous);
    }
    changed &= ~(1<<Reg);               // tag as checked
	previous = actual;
};

int main()
{
	VMpor();
	RegChangeInit();

//           INS_GROUP  Test#
`10`    newstep(0, -1);  // make sure last group has all changes listed.

    printf("\n%d tests, %d errors\n", tests-1, errors);
return 0;
}
