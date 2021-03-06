# generate a mask surrounding nuclei
# takes all data channels, uses dapi to create a mask,
# then returns a smaller image containing each nucleus
# and writes them to files
# it returns a data frame with information about the cells
# I reccomend changing the file output directories, etc to make it work
# better in the workflow.
create_mask <- function(bright, dapi, gfp, rfp, id, size_cutoff=350, display=TRUE, write=TRUE)
{
  require("EBImage")

  dims <- dim(dapi)
  # work with a normalized image for edge detection
  mask <- normalize(dapi)
  #display(mask, title='Normalized image')
  
  # apply 1 round of local median filtering to smooth
  # out the data and improve edge detection. Ive done this with a
  # 10 pixel width, so it will tend to smooth out features smaller 
  # ~10 px. This could be a user-set parameter
  mask <- medianFilter(mask, 10)
  #display(mask, title='Median filtered image')
  
  # convert to a binary image using a thresholding function.
  # Again, I used a 10 pixel width. These could also be user-set parameters
  mask <- thresh(mask, 10, 10, 0.01)
  #display(mask, title='Binary mask')
  
  # fillHull fills in any holes within the mask. 
  mask <- fillHull(mask)
  #display(mask, title='After fillHull')
  
  # smooth the mask using a erosion/dilation This removes
  # small features at the border of the mask. Brush width must be odd.
  mask <- opening(mask, makeBrush(9, shape='disc'))
  #display(mask, title='After erosion/dilation')
  
  # In some images I found that the opening function generated
  # holes, so this will fill them.
  mask <- fillHull(mask)
  #display(mask, title='After fillHull')
  
  # label each nucleus with a different integer greyscale value
  labeled <- bwlabel(mask)

  # calculate the mean florescence outside the mask. This is probably
  # biased, as it will include some labeling cytoplasm, but most
  # of this signal will be washed out by the background in the
  # rest of the slide. Consider blocking out a 100 px area around
  # each nuc to exclude from bg estimate?
  bg.dapi <- mean(dapi[labeled==0])
  bg.gfp  <- mean(gfp[labeled==0])
  bg.rfp  <- mean(rfp[labeled==0])
  
  nnuc <- max(labeled)
  
  # return an empty data frame if no nuclei are found
  if (nnuc==0)
  {
    cat(paste("Did not find any nuclei in image", id, "\n"))
    return(data.frame(id           = c(),
                      total.nuclei = c(),
                      nucleus      = c(),
                      bg.dapi      = c(),
                      bg.gfp       = c(),
                      bg.rfp       = c(),
                      mean.dapi    = c(),
                      mean.gfp     = c(),
                      mean.rfp     = c(),
                      nuc.volume  = c()))
  }
  
  # Remove anything smaller than a user-set size
  # We should think hard about whether this is a necessary step,
  # and it is probably good to visually inspect channels that print
  # this warning
  for (i in 1:nnuc)
  {
    pixels <- which(labeled==i)
    n <- length(pixels)
    if (n < size_cutoff)
    {
      cat(paste("Removing an object with size", n, "pixels from image", id, "\n"))
      mask[pixels] <- 0
    }
  }
  labeled <- bwlabel(mask)
  #display(mask, title='After size cutoff')
  
  nnuc <- max(labeled)
  
  # Show the whole dapi image with identified nuclei highlighted
  if (write)
  {
    cells     <- rgbImage(blue=normalize(dapi)) 
    segmented <- paintObjects(labeled, cells, col='#ff00ff')
    writeImage(segmented, file=paste0(id,'.outlines.TIFF'))
  }
    
  # warn if multiple nuclei are found
  if (nnuc>1)
  {
    cat(paste("Found", nnuc, "nuclei in image", id, "\n"))
  }
  
  # grab a 100 pixel image surrounding the nucleus
  # we could consider saving the positions of features as well, so
  # we know if things are in the capture site or not, or how
  # separated features are
  features <- computeFeatures.moment(labeled)
  start.x <- round(features[,1])-50
  start.y <- round(features[,2])-50
  end.x   <- start.x + 99
  end.y   <- start.y + 99
  
  # shrink the image if this nucleus is at the image border
  start.x[which(start.x < 1)] <- 1
  start.y[which(start.y < 1)] <- 1
  end.x[which(end.x > dims[1])] <- dims[1]
  end.y[which(end.y > dims[2])] <- dims[2]
  
  # grab the mean fluorescence within identified nuclei
  # other metrics are available if we want them
  mean.dapi <- computeFeatures.basic(labeled, dapi)[,1]
  mean.rfp  <- computeFeatures.basic(labeled, rfp)[,1]
  mean.gfp  <- computeFeatures.basic(labeled, gfp)[,1]
  
  # The area of the nucleus, in pixels. Other metrics are available
  size <- computeFeatures.shape(labeled)[,1]
  
  for (i in 1:nnuc)
  {
    name <- paste0(id,'.',i)
    
    # a zoomed in image of each channel
    this.mask   <- mask[start.x[i]:end.x[i], start.y[i]:end.y[i]]
    this.dapi   <- dapi[start.x[i]:end.x[i], start.y[i]:end.y[i]]
    this.bright <- bright[start.x[i]:end.x[i], start.y[i]:end.y[i]]
    this.rfp    <- rfp[start.x[i]:end.x[i], start.y[i]:end.y[i]]
    this.gfp    <- gfp[start.x[i]:end.x[i], start.y[i]:end.y[i]]

    # zoomed in outlines
    this.label  <- bwlabel(this.mask)
    this.cell   <- rgbImage(blue=normalize(this.dapi)) 
    segmented   <- paintObjects(this.label, this.cell, col='#ff00ff')
    
    # write the zoomed images and outlines
    if (write)
    {
      writeImage(segmented,   file=paste0(name,'.outline.TIFF'))
      writeImage(this.mask,   file=paste0(name,'.mask.TIFF'))
      writeImage(this.bright, file=paste0(name,'.bright.TIFF'))
      writeImage(this.dapi,   file=paste0(name,'.dapi.TIFF'))
      writeImage(this.rfp,    file=paste0(name,'.rfp.TIFF'))
      writeImage(this.gfp,    file=paste0(name,'.gfp.TIFF'))
    }
    
    # show them if you want
    if (display)
    {
      display(segmented)
      display(this.bright)
      display(this.dapi)
      display(this.rfp)
      display(this.gfp)
    }
  }

  return(data.frame(id           = rep(id,nnuc),
                    total.nuclei = rep(nnuc,nnuc),
                    nucleus      = 1:nnuc,
                    bg.dapi      = rep(bg.dapi, nnuc),
                    bg.gfp       = rep(bg.gfp, nnuc),
                    bg.rfp       = rep(bg.rfp, nnuc),
                    mean.dapi    = mean.dapi,
                    mean.gfp     = mean.gfp ,
                    mean.rfp     = mean.rfp ,
                    nuc.volume  = size))
                                 
}

