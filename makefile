D_SOURCES := ${wildcard src/*.d}
#Can replace with location of locally installed gsl-2.1 versions if compiling cluster versions
GSL := ${shell pwd}/gsl
LDC := ldc2
GDC := gdc
DMD := dmd

MIN_GSL_VERSION := 1.6

ifneq (${shell (command -v gsl-config)},)
	GSL_VERSION := ${shell (gsl-config --version; echo ${MIN_GSL_VERSION}) | sort -V | head -1}
endif

CHECK_LDC := ${shell command -v ${LDC} 2> /dev/null}
CHECK_GDC := ${shell command -v ${GDC} 2> /dev/null}
CHECK_DMD := ${shell command -v ${DMD} 2> /dev/null}


ifeq (${GSL_VERSION},${MIN_GSL_VERSION})
	C_SOURCES := src/bootstrap.o
else
	GSL_FILES := ${GSL}/lib/libgsl.a ${GSL}/lib/libgslcblas.a
	C_SOURCES := src/static_bootstrap.o ${GSL_FILES}
endif

ifneq (${CHECK_LDC},)
	COMPILER := ${LDC}
	RELEASE_FLAGS := -Jviews -release -enable-inlining -O -w -oq
	DEBUG_FLAGS := -Jviews -d-debug -g -unittest -w
	OUTPUT_FLAG := -of
ifneq (${GSL_VERSION},${MIN_GSL_VERSION})
	STATIC_FLAGS := -d-version=STATICLINKED -I${GSL}/include
else
	STATIC_FLAGS := -L-lgsl -L-lgslcblas -L-lblas
endif
else
ifneq (${CHECK_GDC},)
	COMPILER := ${GDC}
	RELEASE_FLAGS := -Jviews -frelease -finline-functions -O3 -Werror -Wall
	DEBUG_FLAGS := -Jviews -fdebug -g -funittest -Werror -Wall
	OUTPUT_FLAG := -o
ifneq (${GSL_VERSION},${MIN_GSL_VERSION})
	STATIC_FLAGS := -fversion=STATICLINKED -I${GSL}/include
else
	STATIC_FLAGS := -lgsl -lgslcblas -lblas
endif
else
	COMPILER := ${DMD}
	RELEASE_FLAGS := -Jviews -release -inline -O -noboundscheck
	DEBUG_FLAGS := -Jviews -debug -g -unittest -w
	OUTPUT_FLAG := -of
ifneq (${GSL_VERSION},${MIN_GSL_VERSION})
	STATIC_FLAGS := -version=STATICLINKED -I${GSL}/include
else
	STATIC_FLAGS := -L-lgsl -L-lgslcblas -L-lblas
endif
endif
endif

ifeq (${CHECK_LDC},)
ifeq (${CHECK_LDC},)
ifeq (${CHECK_DMD},)
${error No D compiler found at ${LDC} or ${DMD} or ${GDC}}
endif
endif
endif

CLEAN_OBJECTS := rm -f src/*.o bin/*.o *.o

bin/largeQvalue : ${D_SOURCES} ${C_SOURCES} src/libspline.a
	${COMPILER} ${RELEASE_FLAGS} ${D_SOURCES} ${C_SOURCES} src/libspline.a ${STATIC_FLAGS} ${OUTPUT_FLAG}bin/largeQvalue
	${CLEAN_OBJECTS}

src/libspline.a : src/spline_src/* header/*
	gcc -Iheader/ -c src/spline_src/*.c src/spline_src/*.f
	ar rcs src/libspline.a bsplvd.o bvalue.o bvalus.o dpbfa.o dpbsl.o interv.o sgram.o sinerp.o spline_fit.o sslvrg.o stxwx.o
	rm -f bsplvd.o bvalue.o bvalus.o dpbfa.o dpbsl.o interv.o sgram.o sinerp.o spline_fit.o sslvrg.o stxwx.o

test :  bin/largeQvalue
	./test.sh

.PHONY : test
