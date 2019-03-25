FROM debian:sid as builder

RUN apt-get update
RUN apt-get install --yes wget git subversion python pkg-config clang make cmake opam libicu-dev g++ lsb-release sudo autoconf2.13

RUN mkdir /jsbin

# Set up spidermonkey (version 60.2.3 at time of writing)
RUN apt-get install --yes libmozjs-60-dev
RUN echo '#!/bin/bash\n /usr/bin/js60 $@' > /jsbin/js60
RUN chmod +x /jsbin/js60

# Set up webkit (version 2.22.7 at time of writing)
RUN apt-get install --yes libjavascriptcoregtk-4.0-bin 
RUN echo '#!/bin/bash\n /usr/bin/jsc $@' > /jsbin/jsc
RUN chmod +x /jsbin/jsc

# Set up node
RUN sudo apt-get install --yes nodejs
RUN echo '#!/bin/bash\n /usr/bin/nodejs $@' > /jsbin/node
RUN chmod +x /jsbin/node

# Set up spidermonkey
RUN mkdir /spidermonkey
WORKDIR /spidermonkey
RUN wget --quiet https://ftp.mozilla.org/pub/spidermonkey/releases/45.0.2/mozjs-45.0.2.tar.bz2
RUN tar xfj mozjs-45.0.2.tar.bz2
WORKDIR /spidermonkey/mozjs-45.0.2/js/src
RUN autoconf2.13
RUN mkdir build_OPT.OBJ
WORKDIR /spidermonkey/mozjs-45.0.2/js/src/build_OPT.OBJ

# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=850972
RUN sed -i 's!\[:space:\]![[:space:]]!' ../configure

# https://bugzilla.mozilla.org/show_bug.cgi?id=1270036
RUN mv ../../../modules/src  ../../../modules/zlib

RUN SHELL=/bin/bash ../configure 
RUN make
RUN echo '#!/bin/bash\n /spidermonkey/mozjs-45.0.2/js/src/build_OPT.OBJ/js/src/shell/js $@' > /jsbin/js
RUN chmod +x /jsbin/js

# Set up ChakraCore
RUN mkdir /ChakraCore
WORKDIR /ChakraCore
RUN git init
RUN git remote add origin https://github.com/Microsoft/ChakraCore.git
RUN git fetch --depth 1 origin ffe59396b06c2c006d146ec5ddc08f2a30806914
RUN git checkout -b v1.7.3 ffe59396b06c2c006d146ec5ddc08f2a30806914

# Patch some enum type mismatch bugs
RUN sed -i  -e  '1063s/AsmJsVarType/AsmJsRetType/'  /ChakraCore/lib/Backend/IRBuilderAsmJs.cpp
RUN sed -i  -e  '1671s/AsmJsType/AsmJsRetType/' /ChakraCore/lib/Runtime/Language/AsmJsByteCodeGenerator.cpp
RUN sed -i  -e  '1667s/AsmJsType/AsmJsRetType/' /ChakraCore/lib/Runtime/Language/AsmJsByteCodeGenerator.cpp
RUN sed -i  -e  '1663s/AsmJsType/AsmJsRetType/' /ChakraCore/lib/Runtime/Language/AsmJsByteCodeGenerator.cpp

RUN ./build.sh      --no-icu
RUN echo '#!/bin/bash\n /ChakraCore/out/Release/ch $@' > /jsbin/ch
RUN chmod +x /jsbin/ch

# Set up v8
## (first, install depot_tools)
RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git /depot_tools
RUN echo 'PATH=$PATH:/depot_tools' >> /etc/bash.bashrc
ENV PATH="${PATH}:/depot_tools"
RUN mkdir /v8
WORKDIR /v8
RUN fetch v8
WORKDIR /v8/v8
RUN git fetch --all
RUN git checkout 7.5.9 
RUN tools/dev/v8gen.py -vv x64.release
RUN ninja -C out.gn/x64.release
RUN echo '#!/bin/bash\n /v8/v8/out.gn/x64.release/d8 $@' > /jsbin/d8
RUN chmod +x /jsbin/d8

# Save some space
RUN find /ChakraCore /spidermonkey -name '*.a' -o -name '*.o' | xargs rm
WORKDIR /spidermonkey/mozjs-45.0.2/js/src/build_OPT.OBJ/js/src
RUN rm -r gdb jsapi-tests

FROM debian:sid as runner

RUN apt-get update
RUN apt-get install --yes wget git pkg-config make opam libicu-dev sudo libmozjs-60-dev libjavascriptcoregtk-4.0-bin nodejs


RUN mkdir /spidermonkey
COPY --from=builder /spidermonkey /spidermonkey

RUN mkdir -p /ChakraCore/out
COPY --from=builder /ChakraCore/out /ChakraCore/out

RUN mkdir -p /v8/v8/out.gn/x64.release/
COPY --from=builder /v8/v8/out.gn/x64.release/ /v8/v8/out.gn/x64.release/

RUN mkdir /jsbin
COPY --from=builder /jsbin /jsbin

