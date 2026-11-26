# epis - mail client
.POSIX:

include config.mk

SRC = src/main.c src/util.c src/json.c src/config.c src/net.c src/auth.c \
      src/imap.c src/smtp.c src/maildir.c src/msg.c src/autoconf.c \
      src/llm.c src/fuzzy.c src/cli.c
PKGS = openssl
LIBS = -lresolv $(SYSLIBS_$(UNAME))
# iconv is part of the C library on Linux only
SYSLIBS_Darwin = -liconv
GEN =

GUI_SRC_1 = gui/ui.c gui/view.c gui/edit.c gui/vim.c gui/ex.c \
            gui/list.c gui/undo.c gui/pipe.c gui/select.c gui/render.c gui/font.c \
            gui/clay.c gui/$(WINDOW).c $(BACKEND_$(WINDOW))
GUI_PKGS_1 = freetype2 $(PKGS_$(WINDOW))
GUI_GEN_1 = $(GEN_$(WINDOW))
GUI_DEF_1 = -DEPIS_GUI
GUI_LIBS_1 = $(LIBS_$(WINDOW))

# per windowing backend: renderer sources, packages, generated files
BACKEND_wayland = gui/vulkan.c gui/xkb.c
BACKEND_x11 = gui/vulkan.c gui/xkb.c
BACKEND_cocoa = gui/metal.c
PKGS_wayland = vulkan xkbcommon wayland-client wayland-cursor
PKGS_x11 = vulkan xkbcommon xcb xkbcommon-x11
PKGS_cocoa =
LIBS_cocoa = -framework Cocoa -framework Metal -framework QuartzCore
SPIRV = gui/ui.vert.inc gui/ui.frag.inc
GEN_wayland = $(SPIRV) gui/xdg-shell.h gui/xdg-shell.c \
              gui/xdg-decoration.h gui/xdg-decoration.c
GEN_x11 = $(SPIRV)
GEN_cocoa = gui/ui.metal.inc
WLPROTO = $$($(PKG_CONFIG) --variable=pkgdatadir wayland-protocols)

ALLSRC = $(SRC) $(GUI_SRC_$(GUI))
ALLPKGS = $(PKGS) $(GUI_PKGS_$(GUI))
OBJ = $(ALLSRC:.c=.o) $(PROTO_OBJ_$(WINDOW)_$(GUI))
PROTO_OBJ_wayland_1 = gui/xdg-shell.o gui/xdg-decoration.o

EPIS_CPPFLAGS = $(CPPFLAGS) $(GUI_DEF_$(GUI)) -DVERSION=\"$(VERSION)\" \
                -Isrc -Ilib -Igui $$($(PKG_CONFIG) --cflags $(ALLPKGS))
EPIS_LIBS = $$($(PKG_CONFIG) --libs $(ALLPKGS)) $(LIBS) $(GUI_LIBS_$(GUI)) -lm

all: epis

.c.o:
	$(CC) $(CFLAGS) $(EPIS_CPPFLAGS) -c $< -o $@

$(OBJ): src/epis.h config.mk $(GUI_GEN_$(GUI))
gui/ui.o gui/view.o gui/edit.o gui/list.o gui/undo.o gui/pipe.o gui/select.o gui/render.o gui/font.o \
gui/$(WINDOW).o \
$(BACKEND_$(WINDOW):.c=.o): gui/gui.h gui/editor.h
gui/edit.o gui/vim.o gui/ex.o: gui/editor.h
gui/vim.o gui/ex.o: gui/vim.h
gui/cocoa.o gui/metal.o: gui/objc.h

epis: $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $(OBJ) $(EPIS_LIBS)

gui/ui.vert.inc: shaders/ui.vert
	$(GLSLC) -mfmt=c -o $@ shaders/ui.vert
gui/ui.frag.inc: shaders/ui.frag
	$(GLSLC) -mfmt=c -o $@ shaders/ui.frag

# the Metal shader is embedded as source and compiled at run time
gui/ui.metal.inc: shaders/ui.metal
	xxd -i < shaders/ui.metal > $@

gui/xdg-shell.h:
	wayland-scanner client-header $(WLPROTO)/stable/xdg-shell/xdg-shell.xml $@
gui/xdg-shell.c:
	wayland-scanner private-code $(WLPROTO)/stable/xdg-shell/xdg-shell.xml $@
gui/xdg-decoration.h:
	wayland-scanner client-header \
		$(WLPROTO)/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml $@
gui/xdg-decoration.c:
	wayland-scanner private-code \
		$(WLPROTO)/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml $@

# protocol and Clay sources are generated or vendored: relax warnings
gui/xdg-shell.o gui/xdg-decoration.o gui/clay.o:
	$(CC) $(CFLAGS) -w $(EPIS_CPPFLAGS) -c $(@:.o=.c) -o $@

clean:
	rm -f epis $(SRC:.c=.o) gui/*.o gui/*.inc gui/xdg-*.[ch]

BINDIR = $(DESTDIR)$(PREFIX)/bin/epis
ICONDIR = $(DESTDIR)$(PREFIX)/icons/hicolor/256x256/apps/epis-icon.png

install: epis
	mkdir -p $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(MANPREFIX)/man1
	cp -f epis $(DESTDIR)$(PREFIX)/bin/epis
	chmod 755 $(DESTDIR)$(PREFIX)/bin/epis
	cp -f epis.1 $(DESTDIR)$(MANPREFIX)/man1/epis.1
	chmod 644 $(DESTDIR)$(MANPREFIX)/man1/epis.1
	mkdir -p $(DESTDIR)$(PREFIX)/icons/hicolor/256x256/apps/
	cp -f epis-icon.png $(DESTDIR)$(PREFIX)/icons/hicolor/256x256/apps/epis-icon.png
	chmod 644 $(DESTDIR)$(PREFIX)/icons/hicolor/256x256/apps/epis-icon.png
	sed 's|@BINDIR@|$(BINDIR)|g' epis.desktop.in > epis.desktop
	sed -i 's|@ICONDIR@|$(ICONDIR)|g' epis.desktop
	mv epis.desktop $(DESTDIR)$(PREFIX)/share/applications/epis.desktop

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/epis $(DESTDIR)$(MANPREFIX)/man1/epis.1
	rm -f $(DESTDIR)$(PREFIX)/icons/hicolor/256x256/apps/epis-icon.png
	rm -f $(DESTDIR)$(PREFIX)/share/applications/epis.desktop

format:
	indent -linux -l80 src/*.c src/*.h gui/ui.c gui/view.c gui/edit.c \
		gui/vim.c gui/ex.c gui/vim.h gui/editor.h gui/select.c gui/list.c gui/undo.c gui/pipe.c \
		gui/render.c gui/font.c gui/vulkan.c gui/metal.c gui/xkb.c \
		gui/wayland.c gui/x11.c gui/cocoa.c gui/objc.h gui/gui.h

.PHONY: all clean install uninstall format
