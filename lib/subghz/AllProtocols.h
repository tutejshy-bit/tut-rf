#ifndef All_Protocols_h
#define All_Protocols_h

#include "protocols/Princeton.h"
#include "protocols/Raw.h"
#include "protocols/BinRAW.h"

namespace {
    struct RegisterAllProtocols {
        RegisterAllProtocols() {
            SubGhzProtocol::registerProtocol("Princeton", createPrincetonProtocol);
            SubGhzProtocol::registerProtocol("RAW", createRawProtocol);
            SubGhzProtocol::registerProtocol("BinRAW", createBinRAWProtocol);
        }
    };

    static RegisterAllProtocols registerAllProtocols;
}

#endif // All_Protocols_h
