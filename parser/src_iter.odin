package main

src_iter_init :: proc(src: string) -> (src_iter: Src_Iter) {
	src_iter.src = src
	return
}

src_iter_peek :: proc(src_iter: ^Src_Iter, ahead: int = 0) -> rune {
	if src_iter.pos+ahead >= len(src_iter.src) {
		return 0
	}

	return cast(rune)src_iter.src[src_iter.pos+ahead]
}

src_iter_going :: proc(src_iter: ^Src_Iter) -> bool {
	return src_iter.pos < len(src_iter.src)
}

src_iter_next :: proc(src_iter: ^Src_Iter) {
	if src_iter.pos >= len(src_iter.src) {
		return
	}

	if src_iter.src[src_iter.pos] == '\n' {
		src_iter.line += 1
		src_iter.column = 0
	} else {
		src_iter.column += 1
	}

	src_iter.pos += 1
	return
}

src_iter_restore :: proc(dst_src_iter: ^Src_Iter, src_src_iter: Src_Iter) {
	dst_src_iter ^= src_src_iter
}
