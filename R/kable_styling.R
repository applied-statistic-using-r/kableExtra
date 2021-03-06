#' HTML table attributes
#'
#' @description This function provides a cleaner approach to modify the style
#' of HTML tables other than using the `table.attr` option in `knitr::kable()`.
#' Currenly, it assumes the HTML document has boot
#'
#' @param kable_input Output of `knitr::kable()` with `format` specified
#' @param bootstrap_options A character vector for bootstrap table options.
#' Please see package vignette or visit the w3schools'
#' \href{https://www.w3schools.com/bootstrap/bootstrap_tables.asp}{Bootstrap Page}
#' for more information. Possible options include `basic`, `striped`,
#' `bordered`, `hover`, `condensed` and `responsive`.
#' @param latex_options A character vector for LaTeX table options. Please see
#' package vignette for more information. Possible options include
#' `basic`, `striped`, `hold_position`, `scale_down`. `striped` will add
#' alternative row colors to the table. It will imports `LaTeX` package `xcolor`
#' if enabled. `hold_position` will "hold" the floating table to the exact
#' position. It is useful when the `LaTeX` table is contained in a `table`
#' environment after you specified captions in `kable()`. It will force the
#' table to stay in the position where it was created in the document.
#' `scale_down` is useful for super wide table. It will automatically adjust
#' the table to page width.
#' @param full_width A `TRUE` or `FALSE` variable controlling whether the HTML
#' table should have 100\% width. Since HTML and pdf have different flavors on
#' the preferable format for `full_width`. If not specified, a HTML table will
#' have full width by default but this option will be set to `FALSE` for a
#' LaTeX table
#' @param position A character string determining how to position the table
#' on a page. Possible values include `left`, `center`, `right`, `float_left`
#' and `float_right`. Please see the package doc site for demonstrations. For
#' a `LaTeX` table, if `float_*` is selected, `LaTeX` package `wrapfig` will be
#' imported.
#' @param font_size A numeric input for table font size
#'
#' @examples x_html <- knitr::kable(head(mtcars), "html")
#' kable_styling(x_html, "striped", position = "left", font_size = 7)
#'
#' x_latex <- knitr::kable(head(mtcars), "latex")
#' kable_styling(x_latex, latex_options = "striped", position = "float_left")
#'
#' @export
kable_styling <- function(kable_input,
                          bootstrap_options = "basic",
                          latex_options = "basic",
                          full_width = NULL,
                          position = "center",
                          font_size = NULL) {

  if (length(bootstrap_options) == 1 && bootstrap_options == "basic") {
    bootstrap_options <- getOption("kable_styling_bootstrap_options", "basic")
  }
  if (length(latex_options) == 1 && latex_options == "basic") {
    latex_options <- getOption("kable_styling_latex_options", "basic")
  }
  if (position == "center") {
    position <- getOption("kable_styling_position", "center")
  }
  position <- match.arg(position,
                        c("center", "left", "right", "float_left", "float_right"))
  if (is.null(font_size)) {
    font_size <- getOption("kable_styling_font_size", NULL)
  }

  kable_format <- attr(kable_input, "format")

  if (!kable_format %in% c("html", "latex")) {
      message("Currently generic markdown table using pandoc is not supported.")
      return(kable_input)
  }
  if (kable_format == "html") {
    if (is.null(full_width)) {
      full_width <- getOption("kable_styling_full_width", T)
    }
    return(htmlTable_styling(kable_input,
                             bootstrap_options = bootstrap_options,
                             full_width = full_width,
                             position = position,
                             font_size = font_size))
  }
  if (kable_format == "latex") {
    if (is.null(full_width)) {
      full_width <- getOption("kable_styling_full_width", F)
    }
    return(pdfTable_styling(kable_input,
                            latex_options = latex_options,
                            full_width = full_width,
                            position = position,
                            font_size = font_size))
  }
}

# htmlTable Styling ------------
htmlTable_styling <- function(kable_input,
                              bootstrap_options = "basic",
                              full_width = T,
                              position = c("center", "left", "right",
                                           "float_left", "float_right"),
                              font_size = NULL) {
  table_info <- magic_mirror(kable_input)
  kable_xml <- read_xml(as.character(kable_input), options = c("COMPACT"))

  # Modify class
  bootstrap_options <- match.arg(
    bootstrap_options,
    c("basic", "striped", "bordered", "hover", "condensed", "responsive"),
    several.ok = T
  )

  kable_xml_class <- NULL
  if (xml_has_attr(kable_xml, "class")) {
    kable_xml_class <- xml_attr(kable_xml, "class")
  }
  if (length(bootstrap_options) == 1 && bootstrap_options == "basic") {
    bootstrap_options <- "table"
  } else {
    bootstrap_options <- bootstrap_options[bootstrap_options != "basic"]
    bootstrap_options <- paste0("table-", bootstrap_options)
    bootstrap_options <- c("table", bootstrap_options)
  }
  xml_attr(kable_xml, "class") <- paste(c(kable_xml_class, bootstrap_options),
                                        collapse = " ")

  # Modify style
  kable_xml_style <- NULL
  if (xml_has_attr(kable_xml, "style")) {
    kable_xml_style <- xml_attr(kable_xml, "style")
  }
  if (!is.null(font_size)) {
    kable_xml_style <- c(kable_xml_style,
                         paste0("font-size: ", font_size, "px;"))
    kable_caption_node <- xml_tpart(kable_xml, "caption")
    if (!is.null(kable_caption_node)) {
      xml_attr(kable_caption_node, "style") <- "font-size: initial !important;"
    }
  }
  if (!full_width) {
    kable_xml_style <- c(kable_xml_style, "width: auto !important;")
  }

  position <- match.arg(position)
  position_style <- switch(
    position,
    center = "margin-left: auto; margin-right: auto;",
    left = "text-align: right;",
    right = "margin-right: 0; margin-left: auto",
    float_left = "float: left; margin-right: 10px;",
    float_right = "float: right; margin-left: 10px;"
  )
  kable_xml_style <- c(kable_xml_style, position_style)

  if (length(kable_xml_style) != 0) {
    xml_attr(kable_xml, "style") <- paste(kable_xml_style, collapse = " ")
  }

  out <- structure(as.character(kable_xml), format = "html",
                   class = "knitr_kable")
  attr(out, "original_kable_meta") <- table_info
  return(out)
}

# LaTeX table style
pdfTable_styling <- function(kable_input,
                             latex_options = "basic",
                             full_width = F,
                             position = c("center", "left", "right",
                                          "float_left", "float_right"),
                             font_size = NULL) {

  latex_options <- match.arg(
    latex_options,
    c("basic", "striped", "hold_position", "scale_down"),
    several.ok = T
  )

  out <- NULL
  out <- as.character(kable_input)
  table_info <- magic_mirror(kable_input)

  if ("striped" %in% latex_options) {
    out <- styling_latex_striped(out)
  }

  # hold_position is only meaningful in a table environment
  if ("hold_position" %in% latex_options & table_info$table_env) {
    out <- styling_latex_hold_position(out)
  }

  if ("scale_down" %in% latex_options) {
    out <- styling_latex_scale_down(out, table_info)
  }

  if (full_width) {
    out <- styling_latex_full_width(out, table_info)
  }

  if (!is.null(font_size)) {
    out <- styling_latex_font_size(out, table_info, font_size)
  }

  position <- match.arg(position)
  out <- styling_latex_position(out, table_info, position, latex_options)

  out <- structure(out, format = "latex", class = "knitr_kable")
  attr(out, "original_kable_meta") <- table_info
  return(out)
}

styling_latex_striped <- function(x) {
  usepackage_latex("xcolor", "table")
  paste0(
    # gray!6 is the same as shadecolor ({RGB}{248, 248, 248}) in pdf_document
    "\\rowcolors{2}{gray!6}{white}\n", x, "\n\\rowcolors{2}{white}{white}")
}

styling_latex_hold_position <- function(x) {
  sub("\\\\begin\\{table\\}", "\\\\begin\\{table\\}[!h]", x)
}

styling_latex_scale_down <- function(x, table_info) {
  # You cannot put longtable in a resizebox
  # http://tex.stackexchange.com/questions/83457/how-to-resize-or-scale-a-longtable-revised
  if (table_info$tabular == "longtable") {
    warning("Longtable cannot be resized.")
    return(x)
  }
  x <- sub(table_info$begin_tabular,
           paste0("\\\\resizebox\\{\\\\linewidth\\}\\{\\!\\}\\{",
                  table_info$begin_tabular),
           x)
  sub(table_info$end_tabular, paste0(table_info$end_tabular, "\\}"), x)
}

styling_latex_full_width <- function(x, table_info) {
  size_matrix <- sapply(sapply(table_info$contents, str_split, " & "), nchar)
  col_max_length <- apply(size_matrix, 1, max) + 4
  col_ratio <- round(col_max_length / sum(col_max_length), 2)
  col_align <- paste0("p{\\\\dimexpr", col_ratio,
                      "\\\\columnwidth-2\\\\tabcolsep}")
  col_align <- paste0("{", paste(col_align, collapse = ""), "}")
  x <- sub(paste0(table_info$begin_tabular, "\\{[^\\\\n]*\\}"),
           table_info$begin_tabular, x)
  sub(table_info$begin_tabular,
      paste0(table_info$begin_tabular, col_align), x)
}

styling_latex_position <- function(x, table_info, position, latex_options) {
  hold_position <- "hold_position" %in% latex_options
  switch(
    position,
    center = styling_latex_position_center(x, table_info, hold_position),
    left = styling_latex_position_left(x, table_info),
    right = styling_latex_position_right(x, table_info, hold_position),
    float_left = styling_latex_position_float(x, table_info, "l"),
    float_right = styling_latex_position_float(x, table_info, "r")
  )
}

styling_latex_position_center <- function(x, table_info, hold_position) {
  if (!table_info$table_env & table_info$tabular == "tabular") {
    return(paste0("\\begin{table}[!h]\n\\centering", x, "\n\\end{table}"))
  }
  return(x)
}

styling_latex_position_left <- function(x, table_info) {
  if (table_info$tabular != "longtable") return(sub("\\\\centering\\n", "", x))
  longtable_option <- "\\[l\\]"
  sub(paste0("\\\\begin\\{longtable\\}", table_info$valign2),
      paste0("\\\\begin\\{longtable\\}", longtable_option), x)
}

styling_latex_position_right <- function(x, table_info, hold_position) {
  warning("Position = right is only supported for longtable in LaTeX. ",
          "Setting back to center...")
  styling_latex_position_center(x, table_info, hold_position)
}

styling_latex_position_float <- function(x, table_info, option) {
  if (table_info$tabular == "longtable") {
    warning("wraptable is not supported for longtable.")
    if (option == "l") return(styling_latex_position_left(x, table_info))
    if (option == "r") return(styling_latex_position_right(x, table_info, F))
  }
  usepackage_latex("wrapfig")
  size_matrix <- sapply(sapply(table_info$contents, str_split, " & "), nchar)
  col_max_length <- apply(size_matrix, 1, max) + 4
  if (table_info$table_env) {
    option <- sprintf("\\\\begin\\{wraptable\\}\\{%s\\}", option)
    option <- paste0(option, "\\{",sum(col_max_length) * 0.15, "cm\\}")
    x <- sub("\\\\begin\\{table\\}\\[\\!h\\]", "\\\\begin\\{table\\}", x)
    x <- sub("\\\\begin\\{table\\}", option, x)
    x <- sub("\\\\end\\{table\\}", "\\\\end\\{wraptable\\}", x)
  } else {
    option <- sprintf("\\begin{wraptable}{%s}", option)
    option <- paste0(option, "{",sum(col_max_length) * 0.15, "cm}")
    x <- paste0(option, x, "\\end{wraptable}")
  }
  return(x)
}

styling_latex_font_size <- function(x, table_info, font_size) {
  row_height <- font_size + 2
  if (table_info$tabular == "tabular" & table_info$table_env) {
    return(sub(table_info$begin_tabular,
               paste0("\\\\fontsize\\{", font_size, "\\}\\{", row_height,
                      "\\}\\\\selectfont\n", table_info$begin_tabular),
               x))
  }
  # For longtable and tabular without table environment. Simple wrap around
  # fontsize is good enough
  return(paste0(
    "\\begingroup\\fontsize{", font_size, "}{", row_height, "}\\selectfont\n", x,
    "\\endgroup"
  ))
}
